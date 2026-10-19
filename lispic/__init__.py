"""Register Hy imports and expose the minimal Python console-script bootstrap."""
import hy


def main():
    """Load the Hy CLI after registering its import hook and return its exit status."""
    from .cli import main as run
    return run()
