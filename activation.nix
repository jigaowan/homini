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
      xdg_config)
        printf '%s/%s\n' "$xdg_config_home" "$target_rel"
        ;;
      *)
        log_error "unknown namespace: $namespace"
        return 1
        ;;
    esac
  }

  create_link() {
    local src_path=$1
    local dst_path=$2

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

    while IFS=$'\t' read -r namespace target_rel kind mode store_path || [[ -n "$namespace" ]]; do
      local key="''${namespace}:''${target_rel}"
      local dst_path current_path

      [[ -z "$namespace" ]] && continue
      if [[ -n "''${new_entries[$key]+x}" && "''${new_entries[$key]}" == "$kind"$'\t'"$mode"$'\t'"$store_path" ]]; then
        continue
      fi

      dst_path="$(resolve_target_path "$namespace" "$target_rel")" || return 1
      [[ -L "$dst_path" ]] || continue

      current_path="$(readlink -e "$dst_path" || true)"
      [[ "$current_path" == "$store_path" ]] || continue
      rm "$dst_path"
    done < "$old_manifest"
  }

  switch_gcroots() {
    [[ "$old_path" == "$new_path" ]] && return
    nix-store --realise "$new_path" --add-root "$gcroots" > /dev/null
  }

  load_new_entries() {
    while IFS=$'\t' read -r namespace target_rel kind mode store_path || [[ -n "$namespace" ]]; do
      local key="''${namespace}:''${target_rel}"
      [[ -z "$namespace" ]] && continue
      new_entries[$key]="$kind"$'\t'"$mode"$'\t'"$store_path"
    done < "$new_manifest"
  }

  link_new_entries() {
    local key namespace target_rel kind mode store_path dst_path

    for key in "''${!new_entries[@]}"; do
      IFS=: read -r namespace target_rel <<< "$key"
      IFS=$'\t' read -r kind mode store_path <<< "''${new_entries[$key]}"
      dst_path="$(resolve_target_path "$namespace" "$target_rel")" || return 1
      create_link "$store_path" "$dst_path"
    done
  }

  declare -A new_entries=()

  load_new_entries
  cleanup_old_entries
  switch_gcroots
  link_new_entries
''
