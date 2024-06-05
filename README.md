<img src="./icon.png" width=96 />

# cscheck

### What

Some recent [hubbub][1] around a _silent change of ownership_ of the popular macOS app Bartender prompted me to create this small commandline tool. The purpose of the tool is to output Developer Name, ID and hash of the codesigning cert (fingerprint). This can be integrated into various automated checks to detect casual switch-a-roos.

### How

To use, place the `cscheck` binary in your `$PATH` and execute as:

```
cscheck /path/to/app
```

You can pass >1 argument at once:

```
cscheck /Applications/*.app
```

### Example output

```
$ cscheck /Applications/Screenflick.app
App: /Applications/Screenflick.app
SHA-256 Fingerprint: 72d1436e7885315c580605e994e8a94e4a44a0523e2cde17e95430ae616469be
Developer ID: 28488A87JB
Developer Name: Seth Willits (28488A87JB)
```

### Automation

One way to use this tool is to periodically run it against your entire /Applications directory, and compare it to a set of known-good values.

Here's a simple example of how one could do this:

#### Step 1 (initial setup)
```
cscheck /Applications/*.app > ~/.known_good 2>/dev/null
```
#### Step 2 (compare - run this e.g. once per day)
```
diff -y --suppress-common-lines ~/.known_good <(cscheck /Applications/*.app 2>/dev/null)
```

### AI Disclosure

ChatGPT was used to help generate a portion of this code. Feel free to pass along tips or open issues for any errors or imrpovements! I am not a Swift developer by trade.

[1]: https://news.ycombinator.com/item?id=40584606
