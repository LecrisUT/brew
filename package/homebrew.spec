%define homebrew_user linuxbrew
%define homebrew_directory /home/%{homebrew_user}/.%{homebrew_user}
%define brew_repo https://github.com/Homebrew/brew
# TODO: Temporarily ignoring the `check-rpaths` and shebang test.
# - the rpaths should be patched to absolute paths
%undefine __brp_mangle_shebangs
%global __brp_check_rpaths %{nil}

Summary:   Homebrew package manager
Name:      homebrew
Version:   0.0.0
Release:   %autorelease
License:   BSD-2-clause
Group:     Development/Tools
URL:       https://brew.sh
Source:    %{brew_repo}/archive/refs/tags/%{git_version}.tar.gz#/brew.tar.gz

# See: https://github.com/Homebrew/install/blob/master/install.sh#L211-L214
BuildRequires: git
BuildRequires: sudo

Requires: procps-ng
Requires: file
Requires: gcc
Requires: git >= 2.7.0
Requires: glibc >= 2.13
Requires: ruby >= 2.6.0

%description
The Missing Package Manager for macOS (or Linux)

%global debug_package %{nil}
%global _missing_build_ids_terminate_build 0


%prep
%autosetup -n brew-%{version}


%build
git init
git remote set-url origin %{brew_repo} || git remote add origin %{brew_repo}


%install
install -d "$RPM_BUILD_ROOT%{homebrew_directory}"
cp -r . "$RPM_BUILD_ROOT%{homebrew_directory}"

pushd "$RPM_BUILD_ROOT%{homebrew_directory}"
mkdir -vp Cellar Frameworks etc include lib opt sbin share var/homebrew/linked


%check
export HOMEBREW_NO_ANALYTICS_THIS_RUN=1
export HOMEBREW_NO_ANALYTICS_MESSAGE_OUTPUT=1
$RPM_BUILD_ROOT%{homebrew_directory}/bin/brew config
$RPM_BUILD_ROOT%{homebrew_directory}/bin/brew doctor


%pre
getent passwd %{homebrew_user} >/dev/null || \
    useradd -r -d %{homebrew_directory} -s /sbin/nologin \
    -c "The Homebrew default user" %{homebrew_user}


%post
chown -R "%{homebrew_user}:%{homebrew_user}" %{homebrew_directory}


%preun
if [ $1 == 0 ];then
   userdel %{homebrew_user}
fi


%files
%{homebrew_directory}
%license %{homebrew_directory}/LICENSE.txt
%doc %{homebrew_directory}/CHANGELOG.md
%doc %{homebrew_directory}/CONTRIBUTING.md
%doc %{homebrew_directory}/README.md


%changelog
%autochangelog
