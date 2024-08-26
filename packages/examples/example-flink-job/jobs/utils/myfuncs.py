import logging
def reverse_text(message):
    """
    This is just meant to be an example
    Simple Map function that reverses any text that its given.
    """
    logging.info(f"Reversing Text: {message}")
    return [message[::-1]]
