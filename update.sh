#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

# "tac|tac" for http://stackoverflow.com/a/28879552/433558
dindLatest="$(curl -fsSL 'https://github.com/docker/docker/commits/master/hack/dind.atom'| tac|tac | awk -F '[[:space:]]*[<>/]+' '$2 == "id" && $3 ~ /Commit/ { print $4; exit }')"

dockerVerions="$(git ls-remote --tags https://github.com/docker/docker.git | cut -d$'\t' -f2 | grep '^refs/tags/v[0-9].*$' | sed 's!^refs/tags/v!!; s!\^{}$!!' | sort -ruV)"

for version in "${versions[@]}"; do
	rcGrepV='-v'
	rcVersion="${version%-rc}"
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi
	fullVersion="$(echo "$dockerVerions" | grep $rcGrepV -- '-rc' | grep "^$rcVersion[.]" | head -n1)"
	if [ -z "$fullVersion" ]; then
		echo >&2 "warning: cannot find full version for $version"
		continue
	fi
	bucket='get.docker.com'
	if [ "$rcVersion" != "$version" ]; then
		bucket='test.docker.com'
	fi
	sha256="$(curl -fsSL "https://$bucket/builds/Linux/x86_64/docker-$fullVersion.sha256" | cut -d' ' -f1)"
	(
		set -x
		sed -ri '
			s/^(ENV DOCKER_BUCKET) .*/\1 '"$bucket"'/;
			s/^(ENV DOCKER_VERSION) .*/\1 '"$fullVersion"'/;
			s/^(ENV DOCKER_SHA256) .*/\1 '"$sha256"'/;
			s/^(ENV DIND_COMMIT) .*/\1 '"$dindLatest"'/;
		' "$version/Dockerfile" "$version"/*/Dockerfile
	)
done
