# PHP Version Manager

Translations: [English](README.md) - [Castellano](README.es_ES.md)

## About
phpvm is a version manager for [PHP](https://www.php.net/downloads.php), designed to be installed per-user, and invoked 
per-shell, based on the [nvm](https://github.com/nvm-sh/nvm) project. `phpvm` works on any POSIX-compliant shell 
(sh, dash, ksh, zsh, bash), in particular on these platforms: unix, macOS, and windows WSL.

<a id="installation-and-update"></a>
<a id="install-script"></a>
## Installing and Updating

### Install & Update Script
To **install** or **update** phpvm, you should run the [install script][2]. To do that, you may either download and run 
the script manually, or use the following cURL or Wget command:
```sh
curl -o- https://raw.githubusercontent.com/phpvm/phpvm.sh/master/install.sh | bash
```
```sh
wget -qO- https://raw.githubusercontent.com/phpvm/phpvm.sh/master/install.sh | bash
```

## Usage
To install a specific version of node:
```sh
phpvm install 5.6 # or 7.1, 7.2, 7.3, 7.4, 8.0
```
And then in any new shell just use the installed version:
```sh
phpvm use 5.6 # or 7.1, 7.2, 7.3, 7.4, 8.0
```
To uninstall a specific version of node:
```sh
phpvm uninstall 5.6 # or 7.1, 7.2, 7.3, 7.4, 8.0
```

### Extensions
To install extensions in an active version of PHP:
```sh
phpvm add xml mbstring pdo # list of extensions separated by spaces  
```
To install extensions in an active version of PHP from `composer.json`:
```sh
phpvm add --from-composer
```


# TODO:

* Support non-Ubuntu distros for dependency installation
* Support non-compiled versions of PHP (package installed)


[1]: https://github.com/phpvm/phpvm.sh.git
[2]: https://github.com/phpvm/phpvm.sh/blob/master/install.sh