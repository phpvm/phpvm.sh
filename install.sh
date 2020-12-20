#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

phpvm_has() {
  type "$1" > /dev/null 2>&1
}

phpvm_default_install_dir() {
  [ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.phpvm" || printf %s "${XDG_CONFIG_HOME}/phpvm"
}

phpvm_install_dir() {
  if [ -n "$PHPVM_DIR" ]; then
    printf %s "${PHPVM_DIR}"
  else
    phpvm_default_install_dir
  fi
}

phpvm_latest_version() {
  echo "master"
}

phpvm_profile_is_bash_or_zsh() {
  local TEST_PROFILE
  TEST_PROFILE="${1-}"
  case "${TEST_PROFILE-}" in
    *"/.bashrc" | *"/.bash_profile" | *"/.zshrc")
      return
    ;;
    *)
      return 1
    ;;
  esac
}

#
# Outputs the location to PHPVM depending on:
# * The availability of $PHPVM_SOURCE
# * The method used ("script" or "git" in the script, defaults to "git")
# PHPVM_SOURCE always takes precedence unless the method is "script-phpvm-exec"
#
phpvm_source() {
  local PHPVM_METHOD
  PHPVM_METHOD="$1"
  local PHPVM_SOURCE_URL
  PHPVM_SOURCE_URL="$PHPVM_SOURCE"
  if [ "_$PHPVM_METHOD" = "_script-phpvm-exec" ]; then
    PHPVM_SOURCE_URL="https://raw.githubusercontent.com/phpvm/phpvm.sh/$(phpvm_latest_version)/phpvm-exec"
  elif [ "_$PHPVM_METHOD" = "_script-phpvm-bash-completion" ]; then
    PHPVM_SOURCE_URL="https://raw.githubusercontent.com/phpvm/phpvm.sh/$(phpvm_latest_version)/bash_completion"
  elif [ -z "$PHPVM_SOURCE_URL" ]; then
    if [ "_$PHPVM_METHOD" = "_script" ]; then
      PHPVM_SOURCE_URL="https://raw.githubusercontent.com/phpvm/phpvm.sh/$(phpvm_latest_version)/phpvm.sh"
    elif [ "_$PHPVM_METHOD" = "_git" ] || [ -z "$PHPVM_METHOD" ]; then
      PHPVM_SOURCE_URL="https://github.com/phpvm/phpvm.sh.git"
    else
      echo >&2 "Unexpected value \"$PHPVM_METHOD\" for \$PHPVM_METHOD"
      return 1
    fi
  fi
  echo "$PHPVM_SOURCE_URL"
}

#
# Node.js version to install
#
phpvm_node_version() {
  echo "$NODE_VERSION"
}

phpvm_download() {
  if phpvm_has "curl"; then
    curl --compressed -q "$@"
  elif phpvm_has "wget"; then
    # Emulate curl with wget
    ARGS=$(echo "$*" | command sed -e 's/--progress-bar /--progress=bar /' \
                            -e 's/-L //' \
                            -e 's/--compressed //' \
                            -e 's/-I /--server-response /' \
                            -e 's/-s /-q /' \
                            -e 's/-o /-O /' \
                            -e 's/-C - /-c /')
    # shellcheck disable=SC2086
    eval wget $ARGS
  fi
}

install_phpvm_from_git() {
  local INSTALL_DIR
  INSTALL_DIR="$(phpvm_install_dir)"

  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "=> phpvm is already installed in $INSTALL_DIR, trying to update using git"
    command printf '\r=> '

    local FETCH_OPTION
    if [[ "$(phpvm_latest_version)" != "master" ]]; then
      FETCH_OPTION="tag"
    fi

    command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" fetch origin $FETCH_OPTION "$(phpvm_latest_version)" --depth=1 2> /dev/null || {
      echo >&2 "Failed to update phpvm, run 'git fetch' in $INSTALL_DIR yourself."
      exit 1
    }
  else
    # Cloning to $INSTALL_DIR
    echo "=> Downloading phpvm from git to '$INSTALL_DIR'"
    command printf '\r=> '
    mkdir -p "${INSTALL_DIR}"
    if [ "$(ls -A "${INSTALL_DIR}")" ]; then
      command git init "${INSTALL_DIR}" || {
        echo >&2 'Failed to initialize phpvm repo. Please report this!'
        exit 2
      }
      command git --git-dir="${INSTALL_DIR}/.git" remote add origin "$(phpvm_source)" 2> /dev/null \
        || command git --git-dir="${INSTALL_DIR}/.git" remote set-url origin "$(phpvm_source)" || {
        echo >&2 'Failed to add remote "origin" (or set the URL). Please report this!'
        exit 2
      }
      command git --git-dir="${INSTALL_DIR}/.git" fetch origin tag "$(phpvm_latest_version)" --depth=1 || {
        echo >&2 'Failed to fetch origin with tags. Please report this!'
        exit 2
      }
    else
      command git -c advice.detachedHead=false clone "$(phpvm_source)" -b "$(phpvm_latest_version)" --depth=1 "${INSTALL_DIR}" || {
        echo >&2 'Failed to clone phpvm repo. Please report this!'
        exit 2
      }
    fi
  fi
  command git -c advice.detachedHead=false --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" checkout -f --quiet "$(phpvm_latest_version)"
  if [ -n "$(command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" show-ref refs/heads/master)" ]; then
    if command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" branch --quiet 2>/dev/null; then
      command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" branch --quiet -D master >/dev/null 2>&1
    else
      echo >&2 "Your version of git is out of date. Please update it!"
      command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" branch -D master >/dev/null 2>&1
    fi
  fi

  echo "=> Compressing and cleaning up git repository"
  if ! command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" reflog expire --expire=now --all; then
    echo >&2 "Your version of git is out of date. Please update it!"
  fi
  if ! command git --git-dir="$INSTALL_DIR"/.git --work-tree="$INSTALL_DIR" gc --auto --aggressive --prune=now ; then
    echo >&2 "Your version of git is out of date. Please update it!"
  fi
  return
}

#
# Automatically install Node.js
#
phpvm_install_node() {
  local NODE_VERSION_LOCAL
  NODE_VERSION_LOCAL="$(phpvm_node_version)"

  if [ -z "$NODE_VERSION_LOCAL" ]; then
    return 0
  fi

  echo "=> Installing Node.js version $NODE_VERSION_LOCAL"
  phpvm install "$NODE_VERSION_LOCAL"
  local CURRENT_PHPVM_NODE

  CURRENT_PHPVM_NODE="$(phpvm_version current)"
  if [ "$(phpvm_version "$NODE_VERSION_LOCAL")" == "$CURRENT_PHPVM_NODE" ]; then
    echo "=> Node.js version $NODE_VERSION_LOCAL has been successfully installed"
  else
    echo >&2 "Failed to install Node.js $NODE_VERSION_LOCAL"
  fi
}

install_phpvm_as_script() {
  local INSTALL_DIR
  INSTALL_DIR="$(phpvm_install_dir)"
  local PHPVM_SOURCE_LOCAL
  PHPVM_SOURCE_LOCAL="$(phpvm_source script)"
  local PHPVM_EXEC_SOURCE
  PHPVM_EXEC_SOURCE="$(phpvm_source script-phpvm-exec)"
  local PHPVM_BASH_COMPLETION_SOURCE
  PHPVM_BASH_COMPLETION_SOURCE="$(phpvm_source script-phpvm-bash-completion)"

  # Downloading to $INSTALL_DIR
  mkdir -p "$INSTALL_DIR"
  if [ -f "$INSTALL_DIR/phpvm.sh" ]; then
    echo "=> phpvm is already installed in $INSTALL_DIR, trying to update the script"
  else
    echo "=> Downloading phpvm as script to '$INSTALL_DIR'"
  fi
  phpvm_download -s "$PHPVM_SOURCE_LOCAL" -o "$INSTALL_DIR/phpvm.sh" || {
    echo >&2 "Failed to download '$PHPVM_SOURCE_LOCAL'"
    return 1
  } &
  phpvm_download -s "$PHPVM_EXEC_SOURCE" -o "$INSTALL_DIR/phpvm-exec" || {
    echo >&2 "Failed to download '$PHPVM_EXEC_SOURCE'"
    return 2
  } &
  phpvm_download -s "$PHPVM_BASH_COMPLETION_SOURCE" -o "$INSTALL_DIR/bash_completion" || {
    echo >&2 "Failed to download '$PHPVM_BASH_COMPLETION_SOURCE'"
    return 2
  } &
  for job in $(jobs -p | command sort)
  do
    wait "$job" || return $?
  done
  chmod a+x "$INSTALL_DIR/phpvm-exec" || {
    echo >&2 "Failed to mark '$INSTALL_DIR/phpvm-exec' as executable"
    return 3
  }
}

phpvm_try_profile() {
  if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
    return 1
  fi
  echo "${1}"
}

#
# Detect profile file if not specified as environment variable
# (eg: PROFILE=~/.myprofile)
# The echo'ed path is guaranteed to be an existing file
# Otherwise, an empty string is returned
#
phpvm_detect_profile() {
  if [ "${PROFILE-}" = '/dev/null' ]; then
    # the user has specifically requested NOT to have phpvm touch their profile
    return
  fi

  if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
    echo "${PROFILE}"
    return
  fi

  local DETECTED_PROFILE
  DETECTED_PROFILE=''

  if [ -n "${BASH_VERSION-}" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    fi
  elif [ -n "${ZSH_VERSION-}" ]; then
    DETECTED_PROFILE="$HOME/.zshrc"
  fi

  if [ -z "$DETECTED_PROFILE" ]; then
    for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zshrc"
    do
      if DETECTED_PROFILE="$(phpvm_try_profile "${HOME}/${EACH_PROFILE}")"; then
        break
      fi
    done
  fi

  if [ -n "$DETECTED_PROFILE" ]; then
    echo "$DETECTED_PROFILE"
  fi
}

#
# Check whether the user has any globally-installed npm modules in their system
# Node, and warn them if so.
#
phpvm_check_global_modules() {
  local NPM_COMMAND
  NPM_COMMAND="$(command -v npm 2>/dev/null)" || return 0
  [ -n "${PHPVM_DIR}" ] && [ -z "${NPM_COMMAND%%$PHPVM_DIR/*}" ] && return 0

  local NPM_VERSION
  NPM_VERSION="$(npm --version)"
  NPM_VERSION="${NPM_VERSION:--1}"
  [ "${NPM_VERSION%%[!-0-9]*}" -gt 0 ] || return 0

  local NPM_GLOBAL_MODULES
  NPM_GLOBAL_MODULES="$(
    npm list -g --depth=0 |
    command sed -e '/ npm@/d' -e '/ (empty)$/d'
  )"

  local MODULE_COUNT
  MODULE_COUNT="$(
    command printf %s\\n "$NPM_GLOBAL_MODULES" |
    command sed -ne '1!p' |                     # Remove the first line
    wc -l | command tr -d ' '                   # Count entries
  )"

  if [ "${MODULE_COUNT}" != '0' ]; then
    # shellcheck disable=SC2016
    echo '=> You currently have modules installed globally with `npm`. These will no'
    # shellcheck disable=SC2016
    echo '=> longer be linked to the active version of Node when you install a new node'
    # shellcheck disable=SC2016
    echo '=> with `phpvm`; and they may (depending on how you construct your `$PATH`)'
    # shellcheck disable=SC2016
    echo '=> override the binaries of modules installed with `phpvm`:'
    echo

    command printf %s\\n "$NPM_GLOBAL_MODULES"
    echo '=> If you wish to uninstall them at a later point (or re-install them under your'
    # shellcheck disable=SC2016
    echo '=> `phpvm` Nodes), you can remove them from the system Node as follows:'
    echo
    echo '     $ phpvm use system'
    echo '     $ npm uninstall -g a_module'
    echo
  fi
}

phpvm_do_install() {
  if [ -n "${PHPVM_DIR-}" ] && ! [ -d "${PHPVM_DIR}" ]; then
    if [ -e "${PHPVM_DIR}" ]; then
      echo >&2 "File \"${PHPVM_DIR}\" has the same name as installation directory."
      exit 1
    fi

    if [ "${PHPVM_DIR}" = "$(phpvm_default_install_dir)" ]; then
      mkdir "${PHPVM_DIR}"
    else
      echo >&2 "You have \$PHPVM_DIR set to \"${PHPVM_DIR}\", but that directory does not exist. Check your profile files and environment."
      exit 1
    fi
  fi
  if [ -z "${METHOD}" ]; then
    # Autodetect install method
    if phpvm_has git; then
      install_phpvm_from_git
    elif phpvm_has phpvm_download; then
      install_phpvm_as_script
    else
      echo >&2 'You need git, curl, or wget to install phpvm'
      exit 1
    fi
  elif [ "${METHOD}" = 'git' ]; then
    if ! phpvm_has git; then
      echo >&2 "You need git to install phpvm"
      exit 1
    fi
    install_phpvm_from_git
  elif [ "${METHOD}" = 'script' ]; then
    if ! phpvm_has phpvm_download; then
      echo >&2 "You need curl or wget to install phpvm"
      exit 1
    fi
    install_phpvm_as_script
  else
    echo >&2 "The environment variable \$METHOD is set to \"${METHOD}\", which is not recognized as a valid installation method."
    exit 1
  fi

  echo

  local PHPVM_PROFILE
  PHPVM_PROFILE="$(phpvm_detect_profile)"
  local PROFILE_INSTALL_DIR
  PROFILE_INSTALL_DIR="$(phpvm_install_dir | command sed "s:^$HOME:\$HOME:")"

  SOURCE_STR="\\nexport PHPVM_DIR=\"${PROFILE_INSTALL_DIR}\"\\n[ -s \"\$PHPVM_DIR/phpvm.sh\" ] && \\. \"\$PHPVM_DIR/phpvm.sh\"  # This loads phpvm\\n"

  # shellcheck disable=SC2016
  COMPLETION_STR='[ -s "$PHPVM_DIR/bash_completion" ] && \. "$PHPVM_DIR/bash_completion"  # This loads phpvm bash_completion\n'
  BASH_OR_ZSH=false

  if [ -z "${PHPVM_PROFILE-}" ] ; then
    local TRIED_PROFILE
    if [ -n "${PROFILE}" ]; then
      TRIED_PROFILE="${PHPVM_PROFILE} (as defined in \$PROFILE), "
    fi
    echo "=> Profile not found. Tried ${TRIED_PROFILE-}~/.bashrc, ~/.bash_profile, ~/.zshrc, and ~/.profile."
    echo "=> Create one of them and run this script again"
    echo "   OR"
    echo "=> Append the following lines to the correct file yourself:"
    command printf "${SOURCE_STR}"
    echo
  else
    if phpvm_profile_is_bash_or_zsh "${PHPVM_PROFILE-}"; then
      BASH_OR_ZSH=true
    fi
    if ! command grep -qc '/phpvm.sh' "$PHPVM_PROFILE"; then
      echo "=> Appending phpvm source string to $PHPVM_PROFILE"
      command printf "${SOURCE_STR}" >> "$PHPVM_PROFILE"
    else
      echo "=> phpvm source string already in ${PHPVM_PROFILE}"
    fi
    # shellcheck disable=SC2016
    if ${BASH_OR_ZSH} && ! command grep -qc '$PHPVM_DIR/bash_completion' "$PHPVM_PROFILE"; then
      echo "=> Appending bash_completion source string to $PHPVM_PROFILE"
      command printf "$COMPLETION_STR" >> "$PHPVM_PROFILE"
    else
      echo "=> bash_completion source string already in ${PHPVM_PROFILE}"
    fi
  fi
  if ${BASH_OR_ZSH} && [ -z "${PHPVM_PROFILE-}" ] ; then
    echo "=> Please also append the following lines to the if you are using bash/zsh shell:"
    command printf "${COMPLETION_STR}"
  fi

  # Source phpvm
  # shellcheck source=/dev/null
  \. "$(phpvm_install_dir)/phpvm.sh"

  phpvm_check_global_modules

  phpvm_install_node

  phpvm_install_dependencies

  phpvm_reset

  echo "=> Close and reopen your terminal to start using phpvm or run the following to use it now:"
  command printf "${SOURCE_STR}"
  if ${BASH_OR_ZSH} ; then
    command printf "${COMPLETION_STR}"
  fi
}

phpvm_install_dependencies() {
  sudo apt-get install software-properties-common -y
  sudo add-apt-repository ppa:ondrej/php
  sudo apt-get update -y
}

#
# Unsets the various functions defined
# during the execution of the install script
#
phpvm_reset() {
  unset -f phpvm_has phpvm_install_dir phpvm_latest_version phpvm_profile_is_bash_or_zsh \
    phpvm_source phpvm_node_version phpvm_download install_phpvm_from_git phpvm_install_node \
    install_phpvm_as_script phpvm_try_profile phpvm_detect_profile phpvm_check_global_modules \
    phpvm_do_install phpvm_reset phpvm_default_install_dir
}

[ "_$PHPVM_ENV" = "_testing" ] || phpvm_do_install

} # this ensures the entire script is downloaded #
