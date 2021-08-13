distro.tar:

# Make expansion to add --build-arg for a variable if it's set.
arg = $${${1}:+--build-arg "${1}=$${${1}}"}

image-id: Dockerfile build.sh os-release
	docker build $(call arg,BUILD_ID) $(call arg,VERSION_ID) --iidfile "$@" --file "$<" .

container-id: image-id
	docker create --cidfile "$@" "$(shell cat "$<")" -- /bin/true

distro.tar: container-id
	docker export --output "$@" "$(shell cat "$<")"
	docker rm -f "$(shell cat "$<")"

.INTERMEDIATE: image-id container-id
