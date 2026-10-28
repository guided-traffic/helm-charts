#!/usr/bin/env bash
# Chart checks shared by the Makefile and the GitHub workflows.
#
#   chart.sh lint          <chart>   repository conventions + helm lint --strict
#   chart.sh unittest      <chart>   helm-unittest suites in charts/<chart>/tests
#   chart.sh kubeconform   <chart>   render and validate against Kubernetes schemas
#   chart.sh check-version <chart> <base-ref>
#                                    a changed chart carries a new, unreleased version
#   chart.sh release-plan            JSON list of charts whose version has no git tag
#
# Tool paths come from the environment (HELM, UNITTEST, KUBECONFORM,
# KUBERNETES_VERSIONS); the Makefile exports them.
set -euo pipefail

REPO_URL=https://github.com/guided-traffic/helm-charts
# CRD schemas for custom resources a chart may render (Certificates,
# ServiceMonitors, ...); core kinds come from kubeconform's default location.
CRD_SCHEMAS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
SEMVER='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'

fail() {
  echo "::error::$*" >&2
  exit 1
}

# Top-level (unindented) key of a Chart.yaml read from stdin, quotes stripped.
chart_field() {
  awk -v k="$1:" 'index($0, k) == 1 { v = $2; gsub(/["'\'']/, "", v); print v; exit }'
}

# Default values plus every charts/<chart>/ci/*-values.yaml, one set per line;
# the default set is the empty line.
values_sets() {
  echo ""
  local f
  for f in "charts/$1"/ci/*-values.yaml; do
    [[ -e $f ]] && echo "$f"
  done
}

cmd_lint() {
  local chart=$1 dir=charts/$1 meta name version source values
  [[ -f $dir/Chart.yaml ]] || fail "$dir/Chart.yaml missing"
  meta=$("$HELM" show chart "$dir")

  [[ $(chart_field apiVersion <<<"$meta") == v2 ]] || fail "$chart: apiVersion must be v2"
  name=$(chart_field name <<<"$meta")
  [[ $name == "$chart" ]] || fail "$chart: Chart.yaml name '$name' must equal the directory name"
  version=$(chart_field version <<<"$meta")
  [[ $version =~ $SEMVER ]] || fail "$chart: version '$version' is not SemVer"
  # The first source becomes org.opencontainers.image.source on the OCI
  # artifact; ghcr.io links the package to the repository through it.
  source=$(awk '$1 == "sources:" { f = 1; next } f && $1 == "-" { print $2; exit } f && /^[^ -]/ { exit }' <<<"$meta")
  [[ $source == "$REPO_URL" ]] || fail "$chart: the first entry of sources must be $REPO_URL (is '$source')"
  [[ -f $dir/README.md ]] || fail "$chart: README.md missing"
  [[ -f $dir/values.schema.json ]] || fail "$chart: values.schema.json missing"

  while IFS= read -r values; do
    echo "--- helm lint $chart ${values:-(default values)}"
    "$HELM" lint --strict "$dir" ${values:+-f "$values"}
  done < <(values_sets "$chart")
}

cmd_unittest() {
  local chart=$1
  compgen -G "charts/$chart/tests/*_test.yaml" >/dev/null || fail "$chart: no test suites in charts/$chart/tests"
  "$UNITTEST" --strict "charts/$chart"
}

cmd_kubeconform() {
  local chart=$1 kube values
  local cache=${KUBECONFORM_CACHE:-.tools/kubeconform-cache}
  mkdir -p "$cache"
  for kube in $KUBERNETES_VERSIONS; do
    while IFS= read -r values; do
      echo "--- kubeconform $chart on Kubernetes $kube ${values:-(default values)}"
      "$HELM" template "$chart" "charts/$chart" --kube-version "$kube" ${values:+-f "$values"} \
        | "$KUBECONFORM" -strict -summary -kubernetes-version "$kube" -cache "$cache" \
          -schema-location default -schema-location "$CRD_SCHEMAS" -
    done < <(values_sets "$chart")
  done
}

version_gt() {
  [[ $1 != "$2" && $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1) == "$1" ]]
}

cmd_check_version() {
  local chart=$1 base=$2 changed head_version base_version
  # tests/ and ci/ are excluded from the package (.helmignore), so changes
  # there need no release.
  changed=$(git diff --name-only "$base"...HEAD -- "charts/$chart" | grep -Ev "^charts/$chart/(tests|ci)/" || true)
  if [[ -z $changed ]]; then
    echo "$chart: no packaged file changed against $base"
    return 0
  fi
  head_version=$(chart_field version <"charts/$chart/Chart.yaml")
  if git cat-file -e "$base:charts/$chart/Chart.yaml" 2>/dev/null; then
    base_version=$(git show "$base:charts/$chart/Chart.yaml" | chart_field version)
    version_gt "$head_version" "$base_version" \
      || fail "$chart: files changed but version $head_version is not greater than $base_version on $base — bump version in charts/$chart/Chart.yaml"
  fi
  if git rev-parse -q --verify "refs/tags/$chart-$head_version" >/dev/null; then
    fail "$chart: $head_version is already released (tag $chart-$head_version)"
  fi
  echo "$chart: $head_version is a new version"
}

cmd_release_plan() {
  local entries=() file chart version
  for file in charts/*/Chart.yaml; do
    chart=$(basename "$(dirname "$file")")
    version=$(chart_field version <"$file")
    if ! git rev-parse -q --verify "refs/tags/$chart-$version" >/dev/null; then
      entries+=("{\"chart\":\"$chart\",\"version\":\"$version\"}")
    fi
  done
  local IFS=,
  echo "[${entries[*]}]"
}

case ${1:-} in
  lint) cmd_lint "$2" ;;
  unittest) cmd_unittest "$2" ;;
  kubeconform) cmd_kubeconform "$2" ;;
  check-version) cmd_check_version "$2" "$3" ;;
  release-plan) cmd_release_plan ;;
  *) fail "usage: $0 {lint|unittest|kubeconform} <chart> | check-version <chart> <base-ref> | release-plan" ;;
esac
