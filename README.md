# local-k8s-setup
Utility scripts I use to setup a local Kubernetes cluster by using Kind and Podman with a local registry and the Nginx ingress controller deployed in the cluster.

The nginx ingress controller is a modified version of the YAML you can find [here](https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx): it exposes port 8080 for http and 8443 for https since it runs on unprivileged Podman and cannot bind to 80 and 443.

## Dependencies

- podman
- jq
- kind
- kubectl


Tested on MacOS Ventura 13.4.1, Podman 4.5.1, kind 0.20.0

## Usage

1. Make sure the dependencies are installed on your system.
2. Execute the script using the following command:

```bash
chmod +x ./setup-kind-with-registry.sh
./setup-kind-with-registry.sh
```

then you can use the Makefile to bring up the environment

```bash
make up
```

and to bring it down

```bash
make down
```

The local registry will be seen as "kind-registry:5000" from inside the cluster.
