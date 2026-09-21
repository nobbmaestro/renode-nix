# renode-nix (v1.17.0)

Nix flake packaging of [Renode](https://github.com/renode/renode), Antmicro's open source simulation and virtual development framework for complex embedded systems.

This flake provides `renode` v1.17.0, a prebuilt Renode distribution for macOS and Linux.

Supported systems:

| System           | Upstream release                            |
| ---------------- | ------------------------------------------- |
| `aarch64-darwin` | `renode-1.17.0.osx-arm64-portable.dmg`      |
| `x86_64-linux`   | `renode-1.17.0.linux-portable.tar.gz`       |
| `aarch64-linux`  | `renode-1.17.0.linux-arm64-portable.tar.gz` |

## Usage

### Run without installing

```sh
nix run github:nobbmaestro/renode-nix
```

### Flake usage

#### Add input

```nix
inputs.renode.url = "github:nobbmaestro/renode-nix";
```

#### Package usage

```nix
environment.systemPackages = [
  renode.packages.aarch64-darwin.default
];
```

or dev shell:

```nix
devShells.default = pkgs.mkShell {
  packages = [
    renode.packages.aarch64-darwin.default
  ];
};
```

### Overlay usage

The flake provides an overlay so `renode` can be used like a normal package from `nixpkgs`:

```nix
{
  inputs.renode.url = "github:nobbmaestro/renode-nix";
  outputs = inputs@{ nixpkgs, renode, ... }:
  let
    system = "aarch64-darwin";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ renode.overlays.default ];
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [ pkgs.renode ];
    };
  };
}
```

After applying the overlay, `pkgs.renode` is available like a normal package.

## Upstream

[https://github.com/renode/renode](https://github.com/renode/renode)
