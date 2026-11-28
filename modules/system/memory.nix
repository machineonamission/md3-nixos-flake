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
#      on zram), swappiness 150 (swap cold anon to zram rather than drop hot
#      expert pages; the fork's SERVE.md recommends >= 100 for the model),
#      watermark_scale_factor 125 (kswapd starts earlier and keeps ~1.25% of
#      RAM free, so foreground allocations don't hit direct-reclaim stalls).
{ ... }:
{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    # Uncompressed capacity as % of RAM: ~15.5 GiB of swapped pages, which
    # costs ~5 GiB of real RAM at 3:1 when full.
    memoryPercent = 50;
    priority = 100; # nvme0n1p3 is -1 (hardware-configuration.nix): used only once zram is full
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 150;
    "vm.page-cluster" = 0;
    "vm.watermark_scale_factor" = 125;
  };

  # Drop-in on systemd's own user.slice (all login sessions). cgroup2 is mounted
  # with memory_recursiveprot, so the protection is shared out to every app
  # inside it without per-unit settings.
  systemd.slices.user.sliceConfig.MemoryLow = "8G";
}
