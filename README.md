philsc dotfiles
===============

These files comprise my collection of rc and other dot files.

The following programs are customized:

* vim
    * vimrc script
    * plugin installation
* bash
    * bashrc script
* tmux
    * configuration file
* git
    * global aliases
    * hooks for ctags

There is also a directory for my scripts for the awesome window manager. I have 
mostly stopped updating it due to the number of changes between releases I 
needed to do. For the next little while it will mostly resemble the default 
rc.lua with a few hotkey customizations.


Installation
------------

I created a script called `install.sh` to setup everything needed to reproduce 
my customized setup.

    git clone https://github.com/philsc/dotfiles.git
    cd dotfiles
    ./install.sh

Get vim to load the customized vimrc on start by making this your `.vimrc`:

    source ~/.vim/vimrc

Similarly, make the following your `.bashrc`:

    . ~/.bash/bashrc


Action Items
------------

There are still a few things I have to iron out. In particular I'd like to make 
it so that the install script automatically sets up the user's bashrc and vimrc 
to load the customized version.
