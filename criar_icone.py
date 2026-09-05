from PIL import Image

img = Image.open("web/motogo-icon-512.png").convert("RGBA")

img.save(
    "windows/runner/resources/app_icon.ico",
    format="ICO",
    sizes=[
        (16, 16),
        (32, 32),
        (48, 48),
        (64, 64),
        (128, 128),
        (256, 256),
    ],
)

print("OK - icone MotoGo criado!")
