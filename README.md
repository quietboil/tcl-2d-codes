# TCL 2D Codes

Two TCL packages - Datamatrix and QR Code - to generate respective 2D codes.

## Installation

Copy `datamatrix` and/or `qrcode` directories into TCL lib location. Consult `info lib` if in doubt where that is.

## Examples

`display_datamatrix.tcl` and `display_qrcode.tcl` scripts could be used to display provided text as a Datamatrix or a QR Code respectively. Their main purpose however is to provide a demo of calling the matrix generation API.

### Datamatrix Demo

```sh
wish display_datamatrix.tcl "Hello, World!" -window .
```

![datamatrix](https://user-images.githubusercontent.com/33463256/127226896-71523329-e994-4ace-ba01-0c1850785b76.png)


### QR Code Demo

```sh
wish display_qrcode.tcl "Hello, World!" -window . -ppm 4
```

![qrcode](https://user-images.githubusercontent.com/33463256/127226913-c43434ef-a63a-40f5-8b85-2ca62c934bbe.png)
