# Poptart 🍞

A tiny macOS app that turns your images into proper app icons. Drop, convert, done.

## Why?

I got tired of manually resizing images to make app icons. Xcode wants specific sizes. The web wants favicons. Everyone wants something different. So I made this little tool that just... does it.

Drop an image on Poptart, and it'll spit out all the icon sizes you need. Need that macOS rounded rectangle for an image without the look? There's a toggle for that. Need an old-school ICNS file? Got you covered. Just want a folder full of PNGs? Sure thing.

## Who's it for?

Anyone who makes apps, websites, or just likes their folders to have nice custom icons. If you've ever found yourself googling "mac app icon sizes" for the hundredth time, this is for you.

## How to use it

1. Drop an image on the window
2. Pick your format (ICNS, AppIconSet, or Web)
3. Toggle the macOS style if you want that 824px-on-1024px rounded rect magic (for ICNS/AppIconSet)
4. Drag the result wherever you want it

The window starts small and grows when you feed it an image. When you're done, just close the window – the app quits like a proper utility should.

## What you get

- **AppIconSet**: All the PNGs Xcode wants for a macOS app (16x16 through 1024x1024, including @2x variants)
- **ICNS**: The classic Mac icon format that Finder still loves
- **Web**: Everything you need for a website (favicon.ico, favicon-16x16.png, favicon-32x32.png, apple-touch-icon.png)

## Building it

It's a standard Xcode project. Open `Poptart.xcodeproj`, hit build, and you're good to go. Requires macOS 14.0 or later because I used all the new SwiftUI goodies.