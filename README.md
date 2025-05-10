# ImmichLens

This app aims to be a simple way to view your photos and videos stored in Immich.

## VS Code

If you want to run this project in VS Code with autocomplete and intellisense, you can use the following steps:

1. Install the xcode build server:
    ```
    $ brew install xcode-build-server
    ```

2. Install the following extensions in VS Code:
    - [Swift][swift]
    - [SweetPad][sweetpad]
3. Open the project in VS Code and run the following command:
    ```
    > SweetPad: Generate Build Server Config
    ```
4. Open the command palette (Cmd+Shift+P) and run the following command:
    ```
    > SweetPad: Start Build Server
    ```
    Docs: [AutoComplete][sweetpad-autocomplete]

More documentation on SweetPad can be found [here][sweetpad-docs]

> Personal note: I am finding that XCode intellisense is quite slow, and isn't always able to take me to the definition 
of a symbol. I.E The generated api client I can't for the life of me get it to navigate to the generated code. I'm not 
sure what I'm doing wrong, but I'm finding that this setup with VS Code is much better for me, and I can do what I 
expect.

[swift]: https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode
[sweetpad]: https://marketplace.visualstudio.com/items?itemName=SweetPad.sweetpad
[sweetpad-docs]: https://sweetpad.hyzyla.dev/docs/intro
[sweetpad-autocomplete]: https://sweetpad.hyzyla.dev/docs/autocomplete