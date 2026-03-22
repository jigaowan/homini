{
  lib,
  pkgs,
  dir,
  file ? { },
}:

let
  activation-script = pkgs.callPackage ./activation.nix { };
  xdgConfig = if file ? xdg_config then file.xdg_config else { };

  hasForbiddenPathSegments =
    value:
    lib.any (segment: segment == "..") (lib.splitString "/" value);

  isRelativePath =
    value:
    value != ""
    && !lib.hasPrefix "/" value
    && !lib.hasInfix "\n" value
    && !lib.hasInfix "\t" value
    && !hasForbiddenPathSegments value;

  isRelativeTarget =
    value:
    isRelativePath value
    && !lib.hasSuffix "/" value;

  normalizeEntry =
    targetRel: entry:
    let
      hasSource = entry ? source && entry.source != null;
      hasText = entry ? text && entry.text != null;
      textPath = pkgs.writeText (
        lib.strings.sanitizeDerivationName "homini-${lib.replaceStrings [ "/" ] [ "-" ] targetRel}"
      ) entry.text;
      storePath =
        if hasSource then
          "${dir}/${entry.source}"
        else
          toString textPath;
      mode = if hasSource then "source" else "text";
      _ =
        assert lib.assertMsg (isRelativeTarget targetRel) ''
          homini.file.xdg_config."${targetRel}" must be a relative path inside XDG_CONFIG_HOME.
        '';
        assert lib.assertMsg (hasSource != hasText) ''
          homini.file.xdg_config."${targetRel}" must set exactly one of source or text.
        '';
        assert lib.assertMsg (!hasSource || isRelativePath entry.source) ''
          homini.file.xdg_config."${targetRel}".source must be a relative path inside homini.dir.
        '';
        true;
    in
    {
      inherit
        mode
        storePath
        targetRel
        ;
    };

  manifestLines = lib.concatStringsSep "\n" (
    map (
      entry:
      "xdg_config\t${entry.targetRel}\t${entry.mode}\t${entry.storePath}"
    ) (lib.mapAttrsToList normalizeEntry xdgConfig)
  );
in
pkgs.runCommand "homini" { } ''
  mkdir -p $out/bin
  cp ${activation-script} $out/bin/homini
  substituteInPlace $out/bin/homini \
    --subst-var-by OUT $out

  cat > $out/manifest.raw <<'EOF'
${manifestLines}
EOF

  : > $out/manifest

  while IFS=$'\t' read -r namespace target_rel mode store_path || [[ -n "$namespace" ]]; do
    [[ -z "$namespace" ]] && continue

    if [[ "$mode" == "source" ]]; then
      if [[ -d "$store_path" ]]; then
        kind='directory'
      elif [[ -f "$store_path" ]]; then
        kind='file'
      else
        echo "homini: source path does not exist: $store_path" >&2
        exit 1
      fi
    else
      kind='file'
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$namespace" \
      "$target_rel" \
      "$kind" \
      "$mode" \
      "$store_path" \
      >> $out/manifest
  done < $out/manifest.raw

  rm $out/manifest.raw
''
