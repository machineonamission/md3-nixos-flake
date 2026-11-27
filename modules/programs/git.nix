# /etc/gitconfig (root + all users); home/melody.nix reuses this identity.
{
  programs.git = {
    enable = true;
    config = {
      user.name = "Melody";
      user.email = "machineonamission@gmail.com";
    };
  };
  # M2 identity — available to root for committing/pushing to GitHub org
  environment.etc."git-m2.conf".text = ''
    [user]
      name = M2
      email = m2@machineonamission.com
  '';
}
