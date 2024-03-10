# jwd's dotfiles

_There are many dotfiles collections; this is mine, ..._  like Brontosaurs
some of this is ancient: portions go back decades. Use at your own risk!

## Intention

The public subset of these you see here may be useful, I've grown to depend on
them daily. Problems? Open an issue and I'll see what I can do.

Current [GNU bash](https://www.gnu.org/software/bash/) - not the old, GPLv2
bash still included with macOS - is the primary target now, with
[zsh](https://www.zsh.org/) getting an occasional workout to insure compatibility.

## Assumptions

The expectation is that these are maintained in a git repository separate from
$HOME; with symbolic links automatically created in the right places to most
of the files here during installation. A small minority get copied to their
destination rather than symlinked because, for me, the filesystem where these
exist is not always available when I first log in. I prefer the symlink to git
repo contents approach so that changes are easily tested by simply firing up a
new shell.

Some aspects of this depend on an environment variable - CM_DIR - that
specifies the local path to this git repo. I depend a lot on
[direnv](https://direnv.net/) for settings like that.

## Installation

`install.sh` creates/updates the links and copies. I use it rather than one of the
dotfile managers so that I am not dependent on tools other than `bash`.

## History

These began as [csh](https://en.wikipedia.org/wiki/C_shell)
initialization and have evolved through
[ksh](https://en.wikipedia.org/wiki/KornShell), `bash` and now `zsh`. 

They originated in days when hard disks were slow and it made sense to
optimize shell initialization performance. I still try to keep them somewhat
operating system agnostic, although lately they tend to emphasize macOS and
Linux derivatives; testing on the latter is becoming rarer. The only Windows
left here is just to show off that at one time these helped me survive on that
platform too.

Aspects of these that might be of interest:

* Over time, as CPUs and disks got faster, various aspects have migrated into
  separate files.
* The use of 'Just In Time', lazy loading of some sets of related functions, some of
  which are rarely used any longer.
* I've adapted most of my crutches to be both `bash` and `zsh` compatible,
  however the latter tend to be less well tested - `bash` is still my
  preferred shell. I avoid the various `zsh` frameworks in favor of knowing
  where and what my customizations are doing. I put effort into being
  compatible with macOS's native bash only where absolutely necessary.
* [shellcheck](https://github.com/koalaman/shellcheck) has saved me from many
  a scripting blunder - recommended.
* Every so often I would un-comment PROFILE_LOG in `.bash_profile` and
  [profile](https://www.rosipov.com/blog/profiling-slow-bashrc/) what takes
  the most time. I've not felt any need to improve things in some time.

Get other ideas from [GitHub](https://dotfiles.github.io/)
