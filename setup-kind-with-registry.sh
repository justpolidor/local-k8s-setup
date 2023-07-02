#!/bin/sh
set -o errexit

inject_local_registry() {
  podman machine ssh "cat << EOF | sudo tee -a /etc/containers/registries.conf
[[registry]]
location = \"localhost:5000\"
insecure = true
EOF"
}

check_if_registry_already_present() {
    podman machine ssh "grep -q "localhost:5000" /etc/containers/registries.conf"
}

check_if_podman_is_running() {
    podman machine list --format json | jq -e -r '.[0].Running'
}

conditional_registry_conf_inject() {
    if check_if_registry_already_present; then
        echo "Registry already present in /etc/containers/registries.conf... Skipping"
    else
        echo "Injecting local registry configuration..."
        inject_local_registry
        echo "Rebooting podman..."
        reboot_podman
    fi
}

reboot_podman() {
    podman machine stop
    podman machine start
}

if check_if_podman_is_running; then
    echo "Podman is running"
    conditional_registry_conf_inject
else
    echo "Podman is not running... I am starting it"
    podman machine start
    conditional_registry_conf_inject
fi

# create registry container unless it already exists
reg_name='kind-registry'
reg_port='5000'
if [ "$(podman inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  podman run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
    registry:2
fi

# create a cluster with the local registry enabled in containerd
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 8080
    hostPort: 8080
    protocol: TCP
  - containerPort: 8443
    hostPort: 8443
    protocol: TCP
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."kind-registry:5000"]
    endpoint = ["http://kind-registry:5000"]
EOF

# connect the registry to the cluster network if not already connected
if [ "$(podman inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  podman network connect "kind" "${reg_name}"
fi

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "kind-registry:5000
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF


