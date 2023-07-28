{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { nixpkgs, devenv, systems, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            pythonEnv = pkgs.python311.withPackages (ps: with ps; [
              python-lsp-server
              python-lsp-ruff
              pylsp-mypy
            ]);
            mypyEnv = pkgs.python310.withPackages (ps: [ ps.mypy ps.types-requests ]);
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  # https://devenv.sh/reference/options/
                  languages = {
                    # Use Nix (for this file)
                    nix.enable = true;
                  };

                  pre-commit = {
                    hooks = {
                      actionlint.enable = true;
                      deadnix.enable = true;
                      nixpkgs-fmt.enable = true;
                      statix.enable = true;
                    };
                  };
                }
              ];
            };
            python = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  # https://devenv.sh/reference/options/
                  languages = {
                    python = {
                      enable = true;
                      package = pythonEnv;
                      venv = {
                        enable = true;
                        # requirements = builtins.readFile ./requirements.txt;
                      };
                    };
                  };

                  packages = with pkgs; [
                    pre-commit
                    ruff
                    protobuf
                    protoc-gen-doc
                    buf
                  ];

                  pre-commit = {
                    hooks = {
                      ruff.enable = true;
                      autoflake.enable = true;
                      black.enable = true;
                      isort.enable = true;
                      mypy.enable = true;
                      actionlint.enable = true;
                    };
                    settings = {
                      mypy.binPath = "${mypyEnv}/bin/mypy";
                    };
                  };
                }
              ];
            };
          });
    };
}
