{ lib, pkgs }:

let
  activation-bin-path = lib.makeBinPath (
    with pkgs;
    [
      nix
      bash
      coreutils
      diffutils
    ]
  );
in
pkgs.writeShellScript "activation-script" ''
  export PATH="${activation-bin-path}"

  log_info() { echo "homini: $@"; }
  log_error() { >&2 echo "homini: $@"; }

  xdg_state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
  xdg_config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
  gcroots="$xdg_state_home/homini/gcroots/homini"
  if [[ -e $gcroots ]]; then
    old_path="$(readlink -e "$gcroots")"
    old_manifest="$(readlink -e "$old_path/manifest")"
  fi
  new_path="@OUT@"
  new_manifest="$(readlink -e "$new_path/manifest")"

  if [[ -n "$old_manifest" && "$old_manifest" != "$new_manifest" ]] && cmp -s "$old_manifest" "$new_manifest"; then
    log_info "no managed file changes"; exit 0
  fi

  if [[ "$old_path" == "$new_path" ]]; then
    log_info "no dotfiles changes"; exit 0
  fi

  resolve_target_path() {
    local namespace=$1
    local target_rel=$2

    case "$namespace" in
      home)
        printf '%s/%s\n' "$HOME" "$target_rel"
        ;;
      xdg_config)
        printf '%s/%s\n' "$xdg_config_home" "$target_rel"
        ;;
      *)
        log_error "unknown namespace: $namespace"
        return 1
        ;;
    esac
  }

  resolve_source_path() {
    local mode=$1
    local source_spec=$2

    case "$mode" in
      source)
        if [[ "$source_spec" = /* ]]; then
          printf '%s\n' "$source_spec"
        else
          printf '%s/%s\n' "$HOME" "$source_spec"
        fi
        ;;
      text)
        printf '%s\n' "$source_spec"
        ;;
      *)
        log_error "unknown source mode: $mode"
        return 1
        ;;
    esac
  }

  detect_source_kind() {
    local source_path=$1

    if [[ -d "$source_path" ]]; then
      printf '%s\n' directory
    elif [[ -f "$source_path" ]]; then
      printf '%s\n' file
    else
      log_error "source path does not exist: $source_path"
      return 1
    fi
  }

  create_link() {
    local src_path=$1
    local dst_path=$2
    local canonical_src canonical_dst

    canonical_src="$(readlink -m -- "$src_path")"
    canonical_dst="$(readlink -m -- "$dst_path")"
    if [[ "$canonical_src" == "$canonical_dst" ]]; then
      log_error "refusing to link path to itself: $dst_path"
      return 1
    fi

    mkdir -p "$(dirname "$dst_path")"

    if [[ -L "$dst_path" ]]; then
      ln -sfnT "$src_path" "$dst_path"
    elif [[ -e "$dst_path" ]]; then
      ln -sbfT "$src_path" "$dst_path"
    else
      ln -sT "$src_path" "$dst_path"
    fi
  }

  cleanup_old_entries() {
    [[ -e "$old_manifest" ]] || return

    while IFS=$'\t' read -r namespace target_rel kind mode source_spec || [[ -n "$namespace" ]]; do
      local key="''${namespace}:''${target_rel}"
      local dst_path current_path source_path

      [[ -z "$namespace" ]] && continue
      if [[ -n "''${new_entries[$key]+x}" && "''${new_entries[$key]}" == "$kind"$'\t'"$mode"$'\t'"$source_spec" ]]; then
        continue
      fi

      dst_path="$(resolve_target_path "$namespace" "$target_rel")" || return 1
      [[ -L "$dst_path" ]] || continue

      source_path="$(resolve_source_path "$mode" "$source_spec")" || return 1
      current_path="$(readlink -- "$dst_path" || true)"
      [[ "$current_path" == "$source_path" ]] || continue
      rm "$dst_path"
    done < "$old_manifest"
  }

  switch_gcroots() {
    [[ "$old_path" == "$new_path" ]] && return
    nix-store --realise "$new_path" --add-root "$gcroots" > /dev/null
  }

  load_new_entries() {
    while IFS=$'\t' read -r namespace target_rel kind mode source_spec || [[ -n "$namespace" ]]; do
      local key="''${namespace}:''${target_rel}"
      [[ -z "$namespace" ]] && continue
      new_entries[$key]="$kind"$'\t'"$mode"$'\t'"$source_spec"
    done < "$new_manifest"
  }

  link_new_entries() {
    local key namespace target_rel kind mode source_spec dst_path source_path

    for key in "''${!new_entries[@]}"; do
      IFS=: read -r namespace target_rel <<< "$key"
      IFS=$'\t' read -r kind mode source_spec <<< "''${new_entries[$key]}"
      dst_path="$(resolve_target_path "$namespace" "$target_rel")" || return 1
      source_path="$(resolve_source_path "$mode" "$source_spec")" || return 1
      detect_source_kind "$source_path" > /dev/null || return 1
      create_link "$source_path" "$dst_path" || return 1
    done
  }

  declare -A new_entries=()

  load_new_entries
  cleanup_old_entries
  switch_gcroots
  link_new_entries
''
