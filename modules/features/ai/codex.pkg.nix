{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  installShellFiles,
  bubblewrap,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
}:

let
  version = "0.153.2";

  # Prebuilt Rust binaries from the upstream GitHub release. The Linux assets
  # are statically linked against musl, so they need no ELF patching.
  targets = {
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "aarch64-darwin" = "aarch64-apple-darwin";
  };

  hashes = {
    "x86_64-unknown-linux-musl" = {
      codex = "sha256-6M0RYAcfcl0qEMq4EHPdaBj8iwljchJdJ+9uZv3wl54=";
      codex-code-mode-host = "sha256-F3pFB7nMf5fxE6wDRpezn2pxqHaovVCP9tf1LzQuvko=";
    };
    "aarch64-unknown-linux-musl" = {
      codex = "sha256-h4aT+bNwMg6iF5P5nqH1aHt9mqHyxzPeaT2ewLqk5io=";
      codex-code-mode-host = "sha256-cP5IXmkZoDi3X3C+capXgqGaXzbuhVlzAekL0cm8vwc=";
    };
    "x86_64-apple-darwin" = {
      codex = "sha256-2EUV3yexQlWhxP4ognull1oJWlFP5nVTMOje5cwh7no=";
      codex-code-mode-host = "sha256-4QWH/Sae5EX33gCnp36kyKROqZhlYsDeIYnAuD8y8Ys=";
    };
    "aarch64-apple-darwin" = {
      codex = "sha256-kd/CcPDfuuwW2BTxqpDU8n503J43hOZABr7zt5/p4Jw=";
      codex-code-mode-host = "sha256-NHHlSmFB+8vpTOyH0UNwNTZn1A81DvFvqgBevBhUMAs=";
    };
  };

  system = stdenv.hostPlatform.system;
  target =
    targets.${system}
      or (throw "codex: no upstream release binary for ${system}; supported systems: ${lib.concatStringsSep ", " (lib.attrNames targets)}");

  fetchAsset =
    name:
    fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/${name}-${target}.tar.gz";
      hash = hashes.${target}.${name};
    };

  codexBinary = fetchAsset "codex";
  codeModeHost = fetchAsset "codex-code-mode-host";

  # Codex shells out to bubblewrap for its sandbox on Linux.
  runtimePath = lib.makeBinPath (lib.optional stdenv.hostPlatform.isLinux bubblewrap);
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = [ makeWrapper ] ++ lib.optional installShellCompletions installShellFiles;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec

    # Codex looks for the code-mode host next to the executable it runs, so both
    # binaries live in libexec and only the wrapper goes on PATH.
    tar -xzf ${codexBinary} -C $out/libexec
    tar -xzf ${codeModeHost} -C $out/libexec
    mv $out/libexec/codex-${target} $out/libexec/codex
    mv $out/libexec/codex-code-mode-host-${target} $out/libexec/codex-code-mode-host
    chmod +x $out/libexec/codex $out/libexec/codex-code-mode-host

    ln -s ../libexec/codex-code-mode-host $out/bin/codex-code-mode-host

    # Inherited from sadjow/codex-cli-nix: a stable executable path is intended
    # to avoid macOS permission resets when Nix store paths change. This package
    # does not create ~/.local/bin/codex; consumers must provide that symlink or
    # set CODEX_EXECUTABLE_PATH to their own stable launcher path.
    makeWrapper $out/libexec/codex $out/bin/codex \
      --set DISABLE_AUTOUPDATER 1 \
      --run 'export CODEX_EXECUTABLE_PATH="''${CODEX_EXECUTABLE_PATH:-$HOME/.local/bin/codex}"' \
      ${lib.optionalString stdenv.hostPlatform.isLinux ''--prefix PATH : "${runtimePath}"''}

    runHook postInstall
  '';

  postInstall = lib.optionalString installShellCompletions ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  meta = {
    description = "OpenAI Codex CLI, the coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = lib.attrNames targets;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
