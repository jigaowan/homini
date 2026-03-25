{
  lib,
  pkgs,
  file ? { },
}:

let
  activation-script = pkgs.callPackage ./activation.nix { };
  xdgConfig = if file ? xdg_config then file.xdg_config else { };
  normalizeSource =
    value:
    if builtins.isPath value then
      toString value
    else
      value;

  isSinglePathValue =
    value:
    value != ""
    && !lib.hasInfix "\n" value
    && !lib.hasInfix "\t" value;

  isAbsolutePath =
    value:
    lib.hasPrefix "/" value;

  hasForbiddenPathSegments =
    value:
    lib.any (segment: segment == "..") (lib.splitString "/" value);

  isRelativePath =
    value:
    isSinglePathValue value
    && !lib.hasPrefix "/" value
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
      sourceSpec =
        if hasSource then
          normalizeSource entry.source
        else
          toString textPath;
      mode = if hasSource then "source" else "text";
      kind = if hasSource then "runtime" else "file";
      _ =
        assert lib.assertMsg (isRelativeTarget targetRel) ''
          homini.file.xdg_config."${targetRel}" must be a relative path inside XDG_CONFIG_HOME.
        '';
        assert lib.assertMsg (hasSource != hasText) ''
          homini.file.xdg_config."${targetRel}" must set exactly one of source or text.
        '';
        assert lib.assertMsg (
          !hasSource
          || (
            let
              source = normalizeSource entry.source;
            in
            isSinglePathValue source && (isAbsolutePath source || isRelativePath source)
          )
        ) ''
          homini.file.xdg_config."${targetRel}".source must be an absolute path or a relative
          path inside the target user's home directory.
        '';
        true;
    in
    {
      inherit
        kind
        mode
        sourceSpec
        targetRel
        ;
    };

  manifestLines = lib.concatStringsSep "\n" (
    map (
      entry:
      "xdg_config\t${entry.targetRel}\t${entry.kind}\t${entry.mode}\t${entry.sourceSpec}"
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

  while IFS=$'\t' read -r namespace target_rel kind mode source_spec || [[ -n "$namespace" ]]; do
    [[ -z "$namespace" ]] && continue

    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$namespace" \
      "$target_rel" \
      "$kind" \
      "$mode" \
      "$source_spec" \
      >> $out/manifest
  done < $out/manifest.raw

  rm $out/manifest.raw
''
