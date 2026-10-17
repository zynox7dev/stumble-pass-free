███████╗██╗   ██╗███╗   ██╗ ██████╗ ██╗  ██╗
╚══███╔╝╚██╗ ██╔╝████╗  ██║██╔═══██╗╚██╗██╔╝
  ███╔╝  ╚████╔╝ ██╔██╗ ██║██║   ██║ ╚███╔╝ 
 ███╔╝    ╚██╔╝  ██║╚██╗██║██║   ██║ ██╔██╗ 
███████╗   ██║   ██║ ╚████║╚██████╔╝██╔╝ ██╗
╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝

# made by the best developer ; )
from pynput import mouse, keyboard
from PIL import ImageGrab
from threading import Event

stop_event = Event()


def rgb_to_hex(rgb):
    """Convert an RGB tuple to a hex color string"""
    return '#{:02x}{:02x}{:02x}'.format(rgb[0], rgb[1], rgb[2]).upper()

def on_click(x, y, button, pressed):
    """Mouse click listener"""
    if button == mouse.Button.right and pressed:
        try:
            screenshot = ImageGrab.grab(all_screens=True)
            # wdym
            rgb = screenshot.getpixel((x, y))
            hex_color = rgb_to_hex(rgb)
            print(f"Right mouse button pressed at X: {x}, Y: {y}, RGB: {rgb}, HEX: {hex_color}")
        except IndexError:
            print(f"Right mouse button pressed at X: {x}, Y: {y}, but coordinates are outside the screen bounds.")

def on_press(key):
    """Key press listener"""
    if key == keyboard.Key.space:
        print("Spacebar pressed. Exiting...")
        stop_event.set()
        return False

with mouse.Listener(on_click=on_click):
    with keyboard.Listener(on_press=on_press):
        stop_event.wait()
