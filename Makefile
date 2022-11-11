.PHONY: build build-gui gui push push-gui pull pull-gui run-gui

TAG = latest
TYPE = slim
BASE_NAME = starcoder
IMAGE_NAME = asia.gcr.io/infostellar-cluster/$(BASE_NAME)

build:
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(TAG) --build-arg BUILD_TYPE=$(TYPE) .
build-gui: gui
gui: TYPE = gui
gui: BASE_NAME = starcoder-gui
gui: build

push: build
	docker push $(IMAGE_NAME):$(TAG)
push-gui: BASE_NAME = starcoder-gui
push-gui: gui push

pull:
	@test $(shell docker images | grep $(IMAGE_NAME) | wc -l) -eq 0 && docker pull $(IMAGE_NAME) || true
pull-gui: BASE_NAME = starcoder-gui
pull-gui: pull

run-gui: MOUNT =
run-gui: RESOLUTION = "1920x1080"
run-gui: BASE_NAME = starcoder-gui
run-gui: gui
	docker run --rm -d -p 6080:80 -e RESOLUTION=$(RESOLUTION) $(MOUNT) -v $(CURDIR):/mnt --name=starcoder-gui $(IMAGE_NAME):latest
	sleep 2 && xdg-open http://localhost:6080
	docker attach starcoder-gui