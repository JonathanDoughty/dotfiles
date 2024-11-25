# jwd's dotfiles

_There are many dotfiles collections; this is mine, ..._  like Brontosaurs
some of this is ancient: portions go back decades. Use at your own risk!

## Intention

You might find this public subset of my dotfiles useful - I've grown to depend
on them daily. Problems? Open an issue and I'll see what I can do.

Relatively current [GNU bash](https://www.gnu.org/software/bash/) - not the
old, GPLv2 bash still included with **macOS** - is the primary target, with
[zsh](https://www.zsh.org/) getting an occasional workout to insure
compatibility. I use this same collection on both **macOS** and various
**Linux** flavors.

## Assumptions

The expectation is that these are maintained in a git repository separate from
`$HOME`; with symbolic links automatically created in the right places to the
files in the repository during installation. A small minority get copied to
their destination rather than symlinked because, for me, the filesystem where
these exist is not always available when I first log in. I prefer the symlink
to git repository contents approach so that changes are easily tested by
simply starting a new shell.

Some aspects of this, on login and initial installation, depend on an
environment variable - CM_DIR - that specifies the path to where local git
repositories live. I depend a lot on [direnv](https://direnv.net/) for
settings like that.

## Installation

`install.sh` creates/updates the links and copies. You *should* get a warning
if an existing file would be overwritten. Symlinks are fair game to be
replaced however. I use this script rather than one of the dotfile managers so
that I am not dependent on tools other than `git` to make a local copy and
`bash` to set things up.

## History

These began as [csh](https://en.wikipedia.org/wiki/C_shell) (believe it or
not) initialization files and have evolved through
[ksh](https://en.wikipedia.org/wiki/KornShell), `bash` and now `zsh`.

They originated decades ago when disks were slow and it made sense to
optimize shell initialization performance. I still try to keep them somewhat
operating system agnostic, although lately they emphasize **macOS** and
**Linux** derivatives; testing on the latter is becoming rarer. The only **Windows**
left here is only a reminder that at one time these helped me survive on that
platform too.

Aspects that might be of interest:

* Over time, as CPUs and disks got faster, various aspects have migrated into
  separate shell scripts that are sourced.
* The use of 'Just In Time', lazy loading of some related bash
  functions, some of which are rarely used any longer so that only stubs
  remain in my shell environments.
* I've adapted most of my crutches to be both `bash` and `zsh` compatible;
  however the latter tend to be less well tested - `bash` is still my default
  shell. I avoid the various `zsh` frameworks in favor of knowing where and
  what my customizations are doing. I'm certain there are better `zsh` ways to
  do many things.
* While I think this is all still compatible with macOS's native bash I put
  effort into that only when absolutely necessary.
* [shellcheck](https://github.com/koalaman/shellcheck) has saved me from many
  a scripting blunder - highly recommended.
* Every so often I'll un-comment PROFILE_LOG in `.bash_profile` and
  [profile](https://www.rosipov.com/blog/profiling-slow-bashrc/) what takes
  the most time. I've not felt any need to improve things in some time.

Other ideas may be gotten from [GitHub](https://dotfiles.github.io/)
