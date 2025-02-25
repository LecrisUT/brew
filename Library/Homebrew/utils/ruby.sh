# When bumping, run `brew vendor-gems --update=--ruby`
# When bumping to a new major/minor version, also update the bounds in the Gemfile
export HOMEBREW_REQUIRED_RUBY_VERSION=2.6.10

# HOMEBREW_LIBRARY is from the user environment
# shellcheck disable=SC2154
test_ruby() {
  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  "$1" --enable-frozen-string-literal --disable=gems,did_you_mean,rubyopt \
    "${HOMEBREW_LIBRARY}/Homebrew/utils/ruby_check_version_script.rb" \
    "${HOMEBREW_REQUIRED_RUBY_VERSION}" 2>/dev/null
}

can_use_ruby_from_path() {
  if [[ -n "${HOMEBREW_DEVELOPER}" || -n "${HOMEBREW_TESTS}" ]] && [[ -n "${HOMEBREW_USE_RUBY_FROM_PATH}" ]]
  then
    return 0
  fi

  return 1
}

find_first_valid_ruby() {
  local ruby_exec
  while IFS= read -r ruby_exec
  do
    if test_ruby "${ruby_exec}"
    then
      echo "${ruby_exec}"
      break
    fi
  done
}

# HOMEBREW_MACOS is set by brew.sh
# HOMEBREW_PATH is set by global.rb
# shellcheck disable=SC2154
find_ruby() {
  if [[ -n "${HOMEBREW_MACOS}" ]] && ! can_use_ruby_from_path
  then
    echo "/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby"
  else
    local valid_ruby

    # Prioritise rubies from the filtered path (/usr/bin etc) unless explicitly overridden.
    if ! can_use_ruby_from_path
    then
      # function which() is set by brew.sh
      # it is aliased to `type -P`
      # shellcheck disable=SC2230
      valid_ruby=$(find_first_valid_ruby < <(which -a ruby))
    fi

    if [[ -z "${valid_ruby}" ]]
    then
      # Same as above
      # shellcheck disable=SC2230
      valid_ruby=$(find_first_valid_ruby < <(PATH="${HOMEBREW_PATH}" which -a ruby))
    fi

    echo "${valid_ruby}"
  fi
}

# HOMEBREW_FORCE_VENDOR_RUBY is from the user environment
# HOMEBREW_MACOS_SYSTEM_RUBY_NEW_ENOUGH are set by brew.sh
# shellcheck disable=SC2154
need_vendored_ruby() {
  if [[ -n "${HOMEBREW_FORCE_VENDOR_RUBY}" || -n "${HOMEBREW_RUBY3}" ]]
  then
    return 0
  elif [[ -n "${HOMEBREW_MACOS_SYSTEM_RUBY_NEW_ENOUGH}" ]] && ! can_use_ruby_from_path
  then
    return 1
  elif ([[ -z "${HOMEBREW_MACOS}" ]] || can_use_ruby_from_path) && test_ruby "${HOMEBREW_RUBY_PATH}"
  then
    return 1
  else
    return 0
  fi
}

# HOMEBREW_LINUX is set by brew.sh
# shellcheck disable=SC2154
setup-ruby-path() {
  local vendor_dir
  local vendor_ruby_root
  local vendor_ruby_path
  local vendor_ruby_terminfo
  local vendor_ruby_latest_version
  local vendor_ruby_current_version
  # When bumping check if HOMEBREW_MACOS_SYSTEM_RUBY_NEW_ENOUGH (in brew.sh)
  # also needs to be changed.
  local ruby_exec
  local upgrade_fail
  local install_fail

  if [[ -n "${HOMEBREW_MACOS}" ]]
  then
    upgrade_fail="Failed to upgrade Homebrew Portable Ruby!"
    install_fail="Failed to install Homebrew Portable Ruby (and your system version is too old)!"
  else
    local advice="
If there's no Homebrew Portable Ruby available for your processor:
- install Ruby ${HOMEBREW_REQUIRED_RUBY_VERSION} with your system package manager (or rbenv/ruby-build)
- make it first in your PATH
- try again
"
    upgrade_fail="Failed to upgrade Homebrew Portable Ruby!${advice}"
    install_fail="Failed to install Homebrew Portable Ruby and cannot find another Ruby ${HOMEBREW_REQUIRED_RUBY_VERSION}!${advice}"
  fi

  vendor_dir="${HOMEBREW_LIBRARY}/Homebrew/vendor"
  vendor_ruby_root="${vendor_dir}/portable-ruby/current"
  vendor_ruby_path="${vendor_ruby_root}/bin/ruby"
  vendor_ruby_terminfo="${vendor_ruby_root}/share/terminfo"
  if [[ -n "${HOMEBREW_RUBY3}" ]]
  then
    vendor_ruby_latest_version="$(cat "${vendor_dir}/portable-ruby-version")"
  else
    vendor_ruby_latest_version="2.6.10_1" # EOL - phasing out
  fi
  vendor_ruby_current_version="$(readlink "${vendor_ruby_root}")"

  unset HOMEBREW_RUBY_PATH

  if [[ "${HOMEBREW_COMMAND}" == "vendor-install" ]]
  then
    return 0
  fi

  if [[ -x "${vendor_ruby_path}" ]]
  then
    HOMEBREW_RUBY_PATH="${vendor_ruby_path}"
    TERMINFO_DIRS="${vendor_ruby_terminfo}"
    if [[ "${vendor_ruby_current_version}" != "${vendor_ruby_latest_version}" ]]
    then
      brew vendor-install ruby || odie "${upgrade_fail}"
    fi
  else
    HOMEBREW_RUBY_PATH="$(find_ruby)"
    if need_vendored_ruby
    then
      brew vendor-install ruby || odie "${install_fail}"
      HOMEBREW_RUBY_PATH="${vendor_ruby_path}"
      TERMINFO_DIRS="${vendor_ruby_terminfo}"
    fi
  fi

  export HOMEBREW_RUBY_PATH
  [[ -n "${HOMEBREW_LINUX}" && -n "${TERMINFO_DIRS}" ]] && export TERMINFO_DIRS
}
