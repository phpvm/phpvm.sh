#!/usr/bin/env bash

phpvm() {
  if [ $# -lt 1 ]; then
    phpvm --help
    return
  fi

  local DEFAULT_IFS
  DEFAULT_IFS=" $(phpvm_echo t | command tr t \\t)
  "

  if [ "${-#*e}" != "$-" ]; then
    set +e
    local EXIT_CODE
    IFS="${DEFAULT_IFS}" phpvm "$@"
    EXIT_CODE=$?
    set -e
    return $EXIT_CODE
  elif [ "${IFS}" != "${DEFAULT_IFS}" ]; then
    IFS="${DEFAULT_IFS}" phpvm "$@"
    return $?
  fi

  local COMMAND
  COMMAND="${1-}"
  shift

  case $COMMAND in
  'add') phpvm_add "$@" ;;
  'use') phpvm_use "$@" ;;
  'install') phpvm_install "$@" ;;
  'uninstall') phpvm_uninstall "$@" ;;
  *)
    phpvm_echo "$COMMAND is a invalid command"
    return 100
    ;;
  esac
}

phpvm_echo() {
  command printf %s\\n "$*" 2>/dev/null
}

phpvm_bin_list() {
  local PHP_BIN_PREFIX="/usr/bin/php*"
  # shellcheck disable=SC2086
  find $PHP_BIN_PREFIX -maxdepth 1 -type f -printf "%f\n"
}

# shellcheck disable=SC2120
phpvm_extension_list_from_composer() {
  local -r EXTENSIONS=$(grep "\"ext-*" <"${1-$(pwd)/composer.json}" | sed -r 's/.*"ext-([a-zA-Z]*)".*/\1/')
  for EXTENSION in $EXTENSIONS; do
    phpvm_add "$EXTENSION"
  done
}

phpvm_add() {
  local -r PHP_ALIAS_VERSION=$(phpvm_current | cut -d'.' -f1,2)
  local PHP_BIN="php$PHP_ALIAS_VERSION"

  case "$@" in
  '--from-composer')
    phpvm_extension_list_from_composer
    shift
    ;;
  *)
    sudo apt install "$PHP_BIN-$1"
    shift
    ;;
  esac
}

phpvm_install() {
  sudo apt install "php$1"
  local IS_INSTALLED=$?
  if [ $IS_INSTALLED -eq 0 ]; then
    phpvm use "$1"
  fi
}

phpvm_uninstall() {
  sudo apt remove "php$1"
  sudo apt autoremove
  for EXTENSION in $(dpkg --get-selections | grep "php$1" | cut -f1); do
    sudo apt remove "$EXTENSION"
  done
}

phpvm_use() {
  sudo update-alternatives --set php /usr/bin/php"$1"
  phpvm_enable_php_module_apache "$1"
}

phpvm_enable_php_module_apache() {
  sudo a2enmod "php$1"
  local IS_MODULE_ENABLED=$?
  if [[ $IS_MODULE_ENABLED -eq 0 ]]; then
    phpvm_disable_all_php_modules_apache
    sudo systemctl restart apache2
  fi
}

phpvm_current() {
  php -v | grep ^PHP | cut -d' ' -f2
}

phpvm_disable_all_php_modules_apache() {
  for PHP_BIN in $(phpvm_bin_list); do
    sudo a2dismod "$PHP_BIN"
  done
}
