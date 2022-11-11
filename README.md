# Starcoder

Before building images it's recommended to pull existing ones to re-use already built layers:
```shell
make pull
```
or
```shell
make pull-gui
```

## StarPass
To build the image for StarPass run:
```shell
make
```

To build and push the image run:
```shell
make push
```

To change the default tag (`latest`), add `TAG=<tag>` to the command:
```shell
make TAG=<tag>
```
```shell
make push TAG=<tag>
```

## GUI
### Build
To build GUI image run:
```shell
make gui
```

### Run locally
This command will run temporary container and open a browser window 
```shell
make run-gui
```
