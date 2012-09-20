#!/usr/bin/env bash

BREWSTRAPRC="${HOME}/.brewstraprc"
WORK_DIR="/tmp/${USER}-brewstrap"
HOMEBREW_URL="http://raw.github.com/mxcl/homebrew/go"
RVM_URL="https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer"
RVM_MIN_VERSION="185"
RBENV_RUBY_VERSION="1.9.3-p125"
RVM_RUBY_VERSION="ruby-1.9.3-p125"
CHEF_MIN_VERSION="10.12.0"
CHEF_LIBRARIAN_MIN_VERSION="0.0.24"
XCODE_DMG_NAME="xcode_4.1_for_lion.dmg"
XCODE_SHA="2a67c713ab1ef7a47356ba86445f6e630c674b17"
XCODE_URL="http://developer.apple.com/downloads/download.action?path=Developer_Tools/xcode_4.1_for_lion/xcode_4.1_for_lion.dmg"
OSX_GCC_INSTALLER_NAME="GCC-10.7-v2.pkg"
OSX_GCC_INSTALLER_URL="https://github.com/downloads/kennethreitz/osx-gcc-installer/GCC-10.7-v2.pkg"
OSX_GCC_INSTALLER_SHA="027a045fc3e34a8839a7b0e40fa2cfb0cc06c652"
ORIGINAL_PWD=`pwd`
GIT_PASSWORD_SCRIPT="${WORK_DIR}/retrieve_git_password.sh"
RUBY_RUNNER=""
USING_RVM=0
USING_RBENV=0
TOTAL=14
STEP=1
clear

GIT_DEBUG=""
if [ ! -z ${DEBUG} ]; then
  GIT_DEBUG="--verbose --progress"
fi

function print_step() {
  echo -e "\033[1m($(( STEP++ ))/${TOTAL}) ${1}\033[0m\n"
}

function print_warning() {
  echo -e "\033[1;33m${1}\033[0m\n"
}

function print_error() {
  echo -e "\033[1;31m${1}\033[0m\n"
  exit 1
}

function attempt_to_download_xcode() {
  TOTAL=12
  echo -e "XCode is not installed or downloaded. Safari will now open to ADC to download XCode."
  echo -e "Upon logging into your ADC account, download the latest XCode DMG file."
  echo -e "Brewstrap will continue when the download is complete. Press Ctrl-C to abort."
  echo -e ""
  echo -e "Alternatively you can abort this and go download it from the App Store. Once doing that,"
  echo -e "re-run this to have it install Xcode for you and continue the process."
  open "${XCODE_URL}"
  SUCCESS="1"
  while [ $SUCCESS -eq "1" ]; do
    if [ -e ~/Downloads/${XCODE_DMG_NAME} ]; then
      for file in $(ls -c1 ~/Downloads/${XCODE_DMG_NAME}); do
        echo "Found ${file}. Verifying..."
        hdiutil verify $file
        SUCCESS=$?
        if [ $SUCCESS -eq "0" ]; then
          XCODE_DMG=$file
          break;
        else
          echo "${file} failed SHA verification. Incomplete download or corrupted file? Try again?"
        fi
      done
    fi
    if [ $SUCCESS -eq "0" ]; then
      break;
    else
      echo "Waiting for XCode download to finish..."
      sleep 30
    fi
  done
}

function attempt_to_download_osx_gcc_installer() {
  TOTAL=12
  echo -e "OSX GCC Installer is not installed or downloaded. Downloading now..."
  echo -e "Brewstrap will continue when the download is complete. Press Ctrl-C to abort."
  curl -L "${OSX_GCC_INSTALLER_URL}" > ${WORK_DIR}/GCC-10.7-v2.pkg
  SUCCESS="1"
  while [ $SUCCESS -eq "1" ]; do
    if [ -e ${WORK_DIR}/${OSX_GCC_INSTALLER_NAME} ]; then
      for file in $(ls -c1 ${WORK_DIR}/${OSX_GCC_INSTALLER_NAME}); do
        echo "Found ${file}. Verifying..."
        test `shasum ${WORK_DIR}/${OSX_GCC_INSTALLER_NAME} | cut -f 1 -d ' '` = "${OSX_GCC_INSTALLER_SHA}"
        SUCCESS=$?
        if [ $SUCCESS -eq "0" ]; then
          OSX_GCC_INSTALLER=$file
          break;
        else
          echo "${file} failed SHA verification. Incomplete download or corrupted file? Try again?"
        fi
      done
    fi
    if [ $SUCCESS -eq "0" ]; then
      break;
    else
      echo "Waiting for OSX GCC Installer download to finish..."
      sleep 30
    fi
  done
}

echo -e "\033[1m\nStarting brewstrap...\033[0m\n"
echo -e "\n"
echo -e "Brewstrap will make sure your machine is bootstrapped and ready to run chef"
echo -e "by making sure XCode, Homebrew and rbenv/RVM and chef are installed. From there it will"
echo -e "kick off a chef-solo run using whatever chef repository of cookbooks you point it at."
echo -e "\n"
echo -e "It expects the chef repo to exist as a public or private repository on github.com"
echo -e "You will need your github credentials so now might be a good time to login to your account."

[[ -s "$BREWSTRAPRC" ]] && source "$BREWSTRAPRC"

if [ -e .rvmrc ]; then
  print_error "Do not run brewstrap from within a directory with an existing .rvmrc!\nIt causes the wrong environment to load."
fi

if [ ! -d $WORK_DIR ]; then
  mkdir -p $WORK_DIR
fi
if [ ! -x $WORK_DIR ]; then
  print_error "Unable to access ${WORK_DIR}! Permissions problem?"
fi

if [ -d /tmp/chef ]; then
  print_step "Found old brewstrap directory, removing and symlinking to ${WORK_DIR}/chef"
  rm -rf /tmp/chef && ln -s ${WORK_DIR}/chef /tmp/chef
fi

print_step "Collecting information.."
if [ -z $GITHUB_LOGIN ]; then
  echo -n "Github Username: "
  stty echo
  read GITHUB_LOGIN
  echo ""
fi

if [ -z $GITHUB_PASSWORD ]; then
  echo -n "Github Password: "
  stty -echo
  read GITHUB_PASSWORD
  echo ""
fi

if [ -z $CHEF_REPO ]; then
  echo -n "Chef Repo (Take the github HTTP URL): "
  stty echo
  read CHEF_REPO
  echo ""
fi
stty echo

rm -f $BREWSTRAPRC
echo "GITHUB_LOGIN=${GITHUB_LOGIN}" >> $BREWSTRAPRC
echo "GITHUB_PASSWORD=${GITHUB_PASSWORD}" >> $BREWSTRAPRC
echo "CHEF_REPO=${CHEF_REPO}" >> $BREWSTRAPRC
chmod 0600 $BREWSTRAPRC

if [ ! -e /usr/local/bin/brew ]; then
  print_step "Installing homebrew"
  ruby -e "$(curl -fsSkL ${HOMEBREW_URL})"
  if [ ! $? -eq 0 ]; then
    print_error "Unable to install homebrew!"
  fi
  # Double check to make sure it really got installed in case the URL changes again
  if [ ! -e /usr/local/bin/brew ]; then
    print_error "Unable to install homebrew!"
  fi
else
  print_step "Homebrew already installed"
fi

if [ ! -e /usr/bin/gcc ]; then
  if [ $XCODE ]; then
    print_step "There is no GCC available, installing XCode"
    if [ ! -d /Developer/Applications/Xcode.app ]; then
      if [ -e /Applications/Install\ Xcode.app ]; then
        print_step "Installing Xcode from the App Store..."
        MPKG_PATH=`find /Applications/Install\ Xcode.app | grep Xcode.mpkg | head -n1`
        sudo installer -verbose -pkg "${MPKG_PATH}" -target /
      else
        print_step "Installing Xcode from DMG..."
        if [ ! -e ~/Downloads/${XCODE_DMG_NAME} ]; then
          attempt_to_download_xcode
        else
          XCODE_DMG=`ls -c1 ~/Downloads/xcode*.dmg | tail -n1`
        fi
        if [ ! -e $XCODE_DMG ]; then
          print_error "Unable to download XCode and it is not installed!"
        fi
        cd `dirname $0`
        mkdir -p /Volumes/Xcode
        hdiutil attach -mountpoint /Volumes/Xcode $XCODE_DMG
        MPKG_PATH=`find /Volumes/Xcode | grep .mpkg | head -n1`
        sudo installer -verbose -pkg "${MPKG_PATH}" -target /
        hdiutil detach -Force /Volumes/Xcode
      fi
    else
      print_step "Xcode already installed"
    fi
  else
    print_step "There is no GCC available, installing the OSX GCC tools. If you want XCode instead, re-run this script with XCODE=true"
    print_step "Installing OSX GCC Installer from package..."
    if [ ! -e ${WORK_DIR}/${OSX_GCC_INSTALLER_NAME} ]; then
      attempt_to_download_osx_gcc_installer
    else
      OSX_GCC_INSTALLER=`ls -c1 ${WORK_DIR}/GCC-*.pkg | tail -n1`
    fi
    if [ ! -e $OSX_GCC_INSTALLER ]; then
      print_error "Unable to download OSX GCC Installer and it is not installed!"
    fi
    cd `dirname $0`
    sudo installer -verbose -pkg ${WORK_DIR}/${OSX_GCC_INSTALLER_NAME} -target /
  fi
fi

GIT_PATH=`which git`
if [ $? != 0 ]; then
  print_step "Brew installing git"
  brew install git
  if [ ! $? -eq 0 ]; then
    print_error "Unable to install git!"
  fi
else
  print_step "Git already installed"
fi

if [ ! -e /usr/bin/gcc-4.2 ]; then
  print_step "must create a link for gcc to gcc-4.2 using sudo"
  sudo ln -fs /usr/bin/gcc /usr/bin/gcc-4.2
fi

if [ ! -e /usr/bin/g++-4.2 ]; then
  print_step "must create a link for g++ to g++-4.2 using sudo"
  sudo ln -fs /usr/bin/g++ /usr/bin/g++-4.2
fi


if [ $RVM ]; then
  RUBY_RUNNER="rvm ${RVM_RUBY_VERSION} exec"
  if [ ! -e ~/.rvm/bin/rvm ]; then
    print_step "Installing RVM (Forced)"
    bash -s stable < <( curl -fsSL ${RVM_URL} )
    if [ ! $? -eq 0 ]; then
      print_error "Unable to install RVM!"
    fi
  else
    RVM_VERSION=`~/.rvm/bin/rvm --version | cut -f 2 -d ' ' | head -n2 | tail -n1 | sed -e 's/\.//g'`
    if [ "${RVM_VERSION}0" -lt "${RVM_MIN_VERSION}0" ]; then
      print_step "RVM needs to be upgraded..."
      ~/.rvm/bin/rvm get 1.8.5
    else
      print_step "RVM already installed"
    fi
  fi

  [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

  if [ ! -e ~/.bash_profile ]; then
      echo "[[ -s \"\$HOME/.rvm/scripts/rvm\" ]] && source \"\$HOME/.rvm/scripts/rvm\"" > ~/.bash_profile
  fi

  rvm list | grep ${RVM_RUBY_VERSION}
  if [ $? -gt 0 ]; then
    print_step "Installing RVM Ruby ${RVM_RUBY_VERSION}"
    gcc --version | head -n1 | grep llvm >/dev/null
    if [ $? -eq 0 ]; then
      export CC="gcc-4.2"
    fi
    rvm install ${RVM_RUBY_VERSION}
    unset CC
    if [ ! $? -eq 0 ]; then
      print_error "Unable to install RVM ${RVM_RUBY_VERSION}"
    fi
  else
    print_step "RVM Ruby ${RVM_RUBY_VERSION} already installed"
  fi
  USING_RVM=1
else
  if [ ! -d ~/.rvm ]; then
    if [ ! -d /usr/local/rvm ]; then
      print_step "Found no RVM on the system, installing rbenv by default. If you wish to use RVM instead, please re-run with RVM=true"
      if [ ! -d ~/.rbenv ]; then
        cd ~/ && git clone ${GIT_DEBUG} git://github.com/sstephenson/rbenv.git .rbenv
      fi
      unset GEM_PATH
      unset GEM_HOME
      unset MY_RUBY_HOME
      (echo $PATH | grep "rbenv") || (test -e ~/.bash_profile  && cat ~/.bash_profile | grep PATH | grep rbenv) || false
      if [ $? -eq 1 ]; then
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
      fi
      grep "rbenv init" ~/.bash_profile
      if [ $? -eq 1 ]; then
        echo "eval \"\$(rbenv init -)\"" >> ~/.bash_profile
      fi
      export PATH=$HOME/.rbenv/bin:$PATH
      if [ ! -d ~/.rbenv/plugins/ruby-build ]; then
        mkdir -p ~/.rbenv/plugins && cd ~/.rbenv/plugins && git clone $GIT_DEBUG git://github.com/sstephenson/ruby-build.git
      fi
      if [ -e /usr/local/bin/rbenv-install ]; then
        brew uninstall ruby-build
      fi
      gcc --version | head -n1 | grep llvm >/dev/null
      if [ $? -eq 0 ]; then
        export CC="gcc-4.2"
      fi
      which rbenv
      if [ $? -eq 1 ]; then
        print_error "Unable to find rbenv in ${PATH} !"
        exit 1
      fi
      rbenv versions | grep ${RBENV_RUBY_VERSION}
      if [ ! $? -eq 0 ]; then
        rbenv install ${RBENV_RUBY_VERSION}
        rbenv rehash
        if [ ! $? -eq 0 ]; then
          print_error "Unable to install rbenv or ruby ${RBENV_RUBY_VERSION}!"
        fi
      fi
      USING_RBENV=1
      RUBY_RUNNER=""
      eval "$(rbenv init -)"
      rbenv shell ${RBENV_RUBY_VERSION}
    else
      print_step "Found multi-user RVM installation. Skipping installation..."
      RUBY_RUNNER="rvm ${RVM_RUBY_VERSION} exec"
      USING_RVM=1
    fi
  else
    print_step "Found local user RVM installation. Skipping installation..."
    RUBY_RUNNER="rvm ${RVM_RUBY_VERSION} exec"
    USING_RVM=1
  fi
fi
${RUBY_RUNNER} gem specification --version ">=${CHEF_MIN_VERSION}" chef 2>&1 | awk 'BEGIN { s = 0 } /^name:/ { s = 1; exit }; END { if(s == 0) exit 1 }'
if [ $? -gt 0 ]; then
  print_step "Installing chef gem"
  ${RUBY_RUNNER} gem install chef --version "${CHEF_MIN_VERSION}"
  if [ $USING_RBENV -eq 1 ]; then
    print_step "Rehashing RBEnv for chef"
    rbenv rehash
  fi
  if [ ! $? -eq 0 ]; then
    print_error "Unable to install chef!"
  fi
else
  print_step "Chef already installed"
fi

if [ ! -f ${GIT_PASSWORD_SCRIPT} ]; then
  echo "grep PASSWORD ~/.brewstraprc | sed s/^.*=//g" > ${GIT_PASSWORD_SCRIPT}
  chmod 700 ${GIT_PASSWORD_SCRIPT}
fi

export GIT_ASKPASS=${GIT_PASSWORD_SCRIPT}

if [ -d ${WORK_DIR}/chef ]; then
  if [ ! -d ${WORK_DIR}/chef/.git ]; then
    print_step "Existing git repo bad? Attempting to remove..."
    rm -rf ${WORK_DIR}/chef
  fi
fi

if [ ! -d ${WORK_DIR}/chef ]; then
  if [ ! -z ${GITHUB_LOGIN} ]; then
    CHEF_REPO=`echo ${CHEF_REPO} | sed -e "s|https://github.com|https://${GITHUB_LOGIN}@github.com|"`
  fi
  print_step "Cloning chef repo (${CHEF_REPO})"
  git clone ${GIT_DEBUG} ${CHEF_REPO} ${WORK_DIR}/chef

  if [ ! $? -eq 0 ]; then
    print_error "Unable to clone repo!"
  fi
  print_step "Updating submodules..."
  if [ -e ${WORK_DIR}/chef/.gitmodules ]; then
    if [ ! -z ${GITHUB_LOGIN} ]; then
      sed -i -e "s|https://github.com|https://${GITHUB_LOGIN}@github.com|" ${WORK_DIR}/chef/.gitmodules
    fi
  fi
  cd ${WORK_DIR}/chef && git submodule update --init
  if [ ! $? -eq 0 ]; then
    print_error "Unable to update submodules!"
  fi
else
  if [ -z ${LOCAL} ]; then
    print_step "Updating chef repo"
    if [ -e ${WORK_DIR}/chef/.rvmrc ]; then
      rvm rvmrc trust ${WORK_DIR}/chef/
    fi
    cd ${WORK_DIR}/chef && git pull && git submodule update --init
    if [ ! $? -eq 0 ]; then
      print_error "Unable to update repo!"
    fi
  else
    print_step "Using local chef repo"
  fi
fi

unset GIT_ASKPASS

if [ ! -e ${WORK_DIR}/chef/node.json ]; then
  print_error "The chef repo provided has no node.json at the toplevel. This is required to know what to run."
fi

if [ ! -e ${WORK_DIR}/chef/solo.rb ]; then
  print_warning "No solo.rb found, writing one..."
  echo "file_cache_path '${WORK_DIR}/chef-solo-brewstrap'" > ${WORK_DIR}/chef/solo.rb
  echo "cookbook_path '${WORK_DIR}/chef/cookbooks'" >> ${WORK_DIR}/chef/solo.rb
fi

if [ -e ${WORK_DIR}/chef/Cheffile ]; then
  print_step "Cheffile detected, checking for librarian"
  ${RUBY_RUNNER} gem specification --version ">=${CHEF_LIBRARIAN_MIN_VERSION}" librarian 2>&1 | awk 'BEGIN { s = 0 } /^name:/ { s = 1; exit }; END { if(s == 0) exit 1 }'
  if [ $? -gt 0 ]; then
    print_step "Installing librarian chef gem"
    ${RUBY_RUNNER} gem install librarian
    if [ $USING_RBENV -eq 1 ]; then
      print_step "Rehasing RBEnv for librarian chef"
      rbenv rehash
    fi
    if [ ! $? -eq 0 ]; then
      print_error "Unable to install librarian chef!"
    fi
  else
    print_step "Librarian Chef already installed"
  fi
  if [ -e ${WORK_DIR}/chef/Gemfile ]; then
    print_step "Installing bundler gem"
    ${RUBY_RUNNER} gem install bundler
    if [ $USING_RBENV -eq 1 ]; then
      print_step "Rehasing RBEnv for bundler"
      rbenv rehash
    fi
    if [ ! $? -eq 0 ]; then
      print_error "Unable to install bundler!"
    fi
    print_step "Bundler already installed"
  fi
  print_step "Kicking off libarian chef"
  BUNDLER_COMMAND="${RUBY_RUNNER} bundle install --without development"
  env ${BUNDLER_COMMAND}
  LIBRARIAN_COMMAND="${RUBY_RUNNER} librarian-chef install --clean"
  env ${LIBRARIAN_COMMAND}
fi

print_step "Kicking off chef-solo (password will be your local user password)"
echo $RUBY_RUNNER | grep "&&"
if [ $? -eq 0 ]; then
  RUBY_RUNNER=""
fi

CHEF_DEBUG=""
if [ ! -z ${DEBUG} ]; then
  CHEF_DEBUG="-l debug"
fi

CHEF_COMMAND="GITHUB_PASSWORD=$GITHUB_PASSWORD GITHUB_LOGIN=$GITHUB_LOGIN ${RUBY_RUNNER} chef-solo -j ${WORK_DIR}/chef/node.json -c ${WORK_DIR}/chef/solo.rb ${CHEF_DEBUG}"
if [ ! -z ${DEBUG} ]; then
  echo $CHEF_COMMAND
fi
sudo -E env ${CHEF_COMMAND}
if [ ! $? -eq 0 ]; then
  print_error "BREWSTRAP FAILED!"
else
  print_step "BREWSTRAP FINISHED"
fi
cd $ORIGINAL_PWD

if [ -n "$PS1" ]; then
  exec bash --login
fi
