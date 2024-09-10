include versions.env

distro.tar:

# Make expansion to add --build-arg for a variable if it's set.
arg = $(if $($(1)),--build-arg "$(1)=$($(1))")

args = BUILD_ID VERSION_ID NERDCTL_VERSION CRI_DOCKERD_VERSION OPENRESTY_VERSION

nerdctl-$(NERDCTL_VERSION).tgz:
	wget -O "$@" \
		"https://github.com/$(NERDCTL_REPO)/releases/download/${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION:v%=%}-linux-amd64.tar.gz"

cri-dockerd-$(CRI_DOCKERD_VERSION).tgz:
	wget -O "$@" \
		"https://github.com/$(CRI_DOCKERD_REPO)/releases/download/${CRI_DOCKERD_VERSION}/cri-dockerd-${CRI_DOCKERD_VERSION:v%=%}.amd64.tgz"
	wget -O "cri-dockerd-$(CRI_DOCKERD_VERSION).LICENSE" \
		"https://raw.githubusercontent.com/$(CRI_DOCKERD_REPO)/$(CRI_DOCKERD_VERSION)/LICENSE"

openresty-$(OPENRESTY_VERSION)-x86_64.tar:
	wget -O "$@" \
	     "https://github.com/$(OPENRESTY_REPO)/releases/download/$(OPENRESTY_VERSION)/$@"

image-id: Dockerfile $(wildcard files/*) nerdctl-$(NERDCTL_VERSION).tgz cri-dockerd-$(CRI_DOCKERD_VERSION).tgz openresty-$(OPENRESTY_VERSION)-x86_64.tar
	docker build $(foreach a,$(args),$(call arg,$(a))) --iidfile "$@" --file "$<" .

container-id: image-id
	docker create --cidfile "$@" "$(shell cat "$<")" -- /bin/true

distro.tar: container-id
	docker export --output "$@" "$(shell cat "$<")"
	docker rm -f "$(shell cat "$<")"

.INTERMEDIATE: image-id container-id
.DELETE_ON_ERROR: # Avoid half-downloaded files
