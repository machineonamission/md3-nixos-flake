# Swap and memory reclaim, tuned for "desktop + tiered LLM on 31 GB".
#
# The problem (measured 2026-11-27, saver mode): the ruriww fork's tiered model
# mmaps a ~94 GiB GGUF and serves its CPU experts from the page cache, so
# llama-swap held ~20 GB of hot file pages. With stock settings the kernel kept
# those and pushed ~14 GB of the desktop's own memory (Firefox, VS Code,
# Electron, plasmashell) to swap on nvme0, which is the same drive the model
# streams experts from at 1-4 GB/s. Switching apps then waited on swap-in
# behind the model's reads (memory PSI "full" ~8%, write bursts of up to
# 1.1 GiB/s of swap-out). RAM was never "unused": the free figure in system
# monitors counts that page cache as available.
#
# The fix, in three parts:
#   1. zram first: swapped pages are compressed in RAM (zstd, ~3:1 for app
#      heaps) instead of written to nvme0. Swap-in costs microseconds and
#      never queues behind the model's expert reads. The disk partition stays
#      as overflow (lower priority).
#   2. user.slice MemoryLow: the first 8 GiB of the desktop's memory is
#      protected from reclaim, so under pressure the kernel shrinks the model's
#      page cache before it swaps the apps you are using (above 8 GiB the
#      desktop competes normally). Costs the model at most that much expert
#      cache while the desktop is busy.
#   3. sysctls for swap-on-RAM: page-cluster 0 (no swap readahead, pointless
#      on zram), swappiness 100 (swap cold anon to zram rather than drop hot
#      expert pages; the fork's SERVE.md recommends >= 100 for the model).
#      See the 2026-11-28 revision below for the fragmentation settings.
#
# 2026-11-28 revision, after repeated global OOM kills (KWin, Firefox, Electron
# apps, finally llama-server) with 38-41 GB of swap FREE: every kill was an
# order-3 (32 KiB contiguous) GFP_KERNEL allocation from the display driver
# failing on FRAGMENTED RAM, not a shortage. The fork pins host memory for the
# GPU (staging, sweep store, indexer keys), which compaction can't move; ~5 GB of
# zram pages and the watermark boost (+1.25 GB on top of `min`, triggered by the
# fragmentation itself) did the rest. So: a big always-free pool (min_free_kbytes
# 1 GiB keeps contiguous blocks around), proactive background compaction, no
# watermark boost, the default kswapd distance, zram halved, swappiness 100.
{ ... }:
{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    # Uncompressed capacity as % of RAM: ~7.8 GiB of swapped pages, ~2.5 GiB of
    # real RAM at 3:1 when full (was 50 %: ~5 GB of zspages at the OOMs).
    memoryPercent = 25;
    priority = 100; # nvme0n1p3 is -1 (hardware-configuration.nix): used only once zram is full
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100; # the fork's recommendation (150 swapped too eagerly)
    "vm.page-cluster" = 0;
    "vm.min_free_kbytes" = 1048576; # 1 GiB always free: room for high-order kernel allocations
    "vm.compaction_proactiveness" = 50; # default 20: defragment in the background, not at allocation time
    "vm.watermark_boost_factor" = 0; # the boost raised `min` by 1.25 GB right when RAM was fragmented
    # vm.watermark_scale_factor: kernel default (10); 125 kept ~400 MB more in reserve for nothing
  };

  # Drop-in on systemd's own user.slice (all login sessions). cgroup2 is mounted
  # with memory_recursiveprot, so the protection is shared out to every app
  # inside it without per-unit settings.
  systemd.slices.user.sliceConfig.MemoryLow = "8G";
}
