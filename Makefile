NERDCTL_VERSION = 0.11.1

IMAGE_TAG=local/rd-wsl-distro
CONTAINER_NAME=rd-wdl-dstro

distro.tar:

# Make expansion to add --build-arg for a variable if it's set.
arg = $(if $($(1)),--build-arg "$(1)=$($(1))")

args = BUILD_ID VERSION_ID NERDCTL_VERSION

nerdctl-$(NERDCTL_VERSION).tgz:
	wget -O "$@" \
		"https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz"

container-id: image-id

distro.tar: Dockerfile build.sh os-release nerdctl-$(NERDCTL_VERSION).tgz
	docker build $(foreach a,$(args),$(call arg,$(a))) --file "$<" --tag $(IMAGE_TAG) .
	docker rm -f $(CONTAINER_NAME) 2> /dev/null
	docker create --name $(CONTAINER_NAME) $(IMAGE_TAG) -- /bin/true
	docker export --output "$@" $(CONTAINER_NAME)
	docker rm -f $(CONTAINER_NAME)

.INTERMEDIATE: image-id container-id
