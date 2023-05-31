RD_NETWORKING_VERSION = 1.1.1
NERDCTL_VERSION = 1.4.0
OPENRESTY_VERSION=0.0.1
CRI_DOCKERD_VERSION = 0.2.6
CRI_DOCKERD_ORG=Mirantis

distro.tar:

# Make expansion to add --build-arg for a variable if it's set.
arg = $(if $($(1)),--build-arg "$(1)=$($(1))")

args = BUILD_ID VERSION_ID RD_NETWORKING_VERSION NERDCTL_VERSION CRI_DOCKERD_VERSION OPENRESTY_VERSION

rd-networking-v$(RD_NETWORKING_VERSION).tgz:
	wget -O "$@" \
		"https://github.com/rancher-sandbox/rancher-desktop-networking/releases/download/v${RD_NETWORKING_VERSION}/rancher-desktop-networking-v${RD_NETWORKING_VERSION}.tar.gz"

nerdctl-$(NERDCTL_VERSION).tgz:
	wget -O "$@" \
		"https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz"

cri-dockerd-$(CRI_DOCKERD_VERSION).tgz:
	wget -O "$@" \
		"https://github.com/$(CRI_DOCKERD_ORG)/cri-dockerd/releases/download/v${CRI_DOCKERD_VERSION}/cri-dockerd-${CRI_DOCKERD_VERSION}.amd64.tgz"
	wget -O "cri-dockerd-$(CRI_DOCKERD_VERSION).LICENSE" \
		"https://raw.githubusercontent.com/$(CRI_DOCKERD_ORG)/cri-dockerd/v$(CRI_DOCKERD_VERSION)/LICENSE"

openresty-v$(OPENRESTY_VERSION)-x86_64.tar:
	wget -O "$@" \
	     "https://github.com/rancher-sandbox/openresty-packaging/releases/download/v$(OPENRESTY_VERSION)/$@"

image-id: Dockerfile $(wildcard files/*) rd-networking-v$(RD_NETWORKING_VERSION).tgz nerdctl-$(NERDCTL_VERSION).tgz cri-dockerd-$(CRI_DOCKERD_VERSION).tgz openresty-v$(OPENRESTY_VERSION)-x86_64.tar
	docker build $(foreach a,$(args),$(call arg,$(a))) --iidfile "$@" --file "$<" .

container-id: image-id
	docker create --cidfile "$@" "$(shell cat "$<")" -- /bin/true

distro.tar: container-id
	docker export --output "$@" "$(shell cat "$<")"
	docker rm -f "$(shell cat "$<")"

.INTERMEDIATE: image-id container-id
