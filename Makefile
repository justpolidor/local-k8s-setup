up:
	echo "setting up environment..."
	./setup-kind-with-registry.sh
	echo "Waiting system pods to be ready..."
	kubectl wait --for=condition=Ready pod --all -n kube-system
	echo "deploying nginx"
	kubectl apply -f nginx.yaml -n ingress-nginx
	echo "ready"

down:
	echo "tearing down the environment"
	kind delete cluster
	podman stop kind-registry && podman rm kind-registry