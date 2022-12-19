# defines an overlay for using this flake via nixpkgs.
final: prev: rec {
  concourse = prev.buildGo118Module rec {
    pname = "concourse";
    version = "7.9.0";
    vendorSha256 = "sha256-nX0r/7V+rgJb3/9O91QskYzBpWXIca7m3Do1QtGuHgg=";
    subPackages = ["cmd/concourse" "fly"];
    src = prev.fetchFromGitHub {
      owner = "concourse";
      repo = "concourse";
      rev = "v${version}";
      sha256 = "sha256-YatN0VG3oEUK+vzJzthRnX+EkvUgKq2uIunAoPMoRag=";
    };
    ldflags = ["-s" "-w" "-X github.com/concourse/concourse.Version=${version}"];
    doCheck = false;
    meta.description = "Concourse CI/CD system";
    meta.homepage = "https://github.com/concourse/concourse";
    overrideModAttrs = _: rec {
      CGO_ENABLED = "0";
      GO111MODULE = "on";
      GOPROXY = "direct";
      GOPRIVATE = "github.com/concourse";
      GOFLAGS = "-trimpath";
      GONOPROXY = GOPRIVATE;
      GONOSUMDB = GOPRIVATE;
    };
  };
}
