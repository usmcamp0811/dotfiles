import json
import argparse
from pdf2image import convert_from_path
from tkinter import Tk, Canvas, Button, simpledialog, Scrollbar, Frame
from PIL import Image, ImageTk
import sys
import os


# Function to process command line arguments
def parse_args():
    parser = argparse.ArgumentParser(
        description="Draw bounding boxes on a PDF and save the results as JSON."
    )
    parser.add_argument(
        "pdf_path", type=str, help="Path to the PDF file to be processed."
    )
    parser.add_argument(
        "output_json",
        type=str,
        help="Path to the output JSON file to save the labeled boxes.",
    )
    parser.add_argument(
        "--page", type=int, default=1, help="Page number to display (default is 1)."
    )
    return parser.parse_args()


# Function to save labeled boxes as JSON
def save_boxes_incrementally(boxes, output_json, page_number):
    # Create a dictionary for all pages if it doesn't exist yet
    if os.path.exists(output_json):
        with open(output_json, "r") as f:
            all_boxes = json.load(f)
    else:
        all_boxes = {}

    # Add the boxes for the current page
    all_boxes[page_number] = boxes

    # Save all boxes to the JSON file
    with open(output_json, "w") as f:
        json.dump(all_boxes, f, indent=4)
    print(f"Saved the boxes and labels to {output_json} for page {page_number}.")


# Function to load the JSON file if it exists
def load_boxes_from_json(output_json, page_number):
    if os.path.exists(output_json):
        with open(output_json, "r") as f:
            all_boxes = json.load(f)
        # Return the boxes for the specified page number, default to empty if not found
        return all_boxes.get(str(page_number), [])
    return []  # Return an empty list if the file doesn't exist


# Convert PDF to images
def convert_pdf_to_images(pdf_path):
    return convert_from_path(pdf_path)


# Function to finish drawing the box (capture label and store)
def finish_draw(event, page_number):
    global current_box, current_label, boxes, output_json
    if current_box:
        current_label = simpledialog.askstring("Input", "Label for the box:")
        if current_label:
            # Convert the flat list [x1, y1, x2, y2] into a list of coordinate pairs
            polygon = [
                [current_box[0], current_box[1]],  # top-left
                [current_box[2], current_box[1]],  # top-right
                [current_box[2], current_box[3]],  # bottom-right
                [current_box[0], current_box[3]],  # bottom-left
            ]

            # Save the box as a polygon (coords)
            boxes.append(
                {
                    "label": current_label,
                    "polygon": polygon,
                }
            )
            save_boxes_incrementally(
                boxes, output_json, page_number
            )  # Pass the page_number to save the boxes for the correct page

            # Draw the label immediately after the new box is added
            draw_label(current_label, polygon)  # Pass the polygon as coordinates

        current_box = []  # Reset the current box


# Function to draw the label for the newly drawn box
def draw_label(label_text, coords):
    label_x = (
        coords[0][0] + 5
    )  # Add a small offset to avoid overlapping with the top-left corner
    label_y = coords[0][1] + 5  # Same for the vertical positioning

    font_size = 15

    # Calculate the width of the label background based on the label text length
    label_width = len(label_text) * font_size * 0.6  # Adjust based on font size
    label_height = font_size + 5  # Height of the text box with padding

    # Draw the background rectangle (white) behind the label
    canvas.create_rectangle(
        label_x - 30,
        label_y - 20,
        label_x + label_width + 20,
        label_y + label_height,
        fill="#9ebbf7",
        outline="blue",
        tags="label_bg",
    )

    # Create the label text (black)
    canvas.create_text(
        label_x,
        label_y,
        text=label_text,
        fill="black",
        font=("Arial", font_size),
        tags="existing_label",
    )


# Function to update the box while drawing (capture the end point)
def update_draw(event):
    global current_box
    if current_box:
        # Remove the previous rectangle and update the current one
        canvas.delete("current_box")
        current_box[2], current_box[3] = event.x, event.y
        canvas.create_rectangle(
            *current_box, outline="red", width=4, tags="current_box"
        )


# Function to start drawing a box (capture the start point)
def start_draw(event):
    global current_box
    current_box = [event.x, event.y, event.x, event.y]  # [x1, y1, x2, y2]


# Function to display the image and draw on it
def display_image(image):
    global canvas
    photo = ImageTk.PhotoImage(image)
    canvas.create_image(0, 0, anchor="nw", image=photo)
    canvas.image = photo  # Store the reference to the image
    # Update the scrollable region based on the image size
    canvas.config(scrollregion=canvas.bbox("all"))


# Function to draw existing boxes from JSON
def draw_existing_boxes(boxes):
    for box in boxes:
        coords = box["polygon"]
        # Draw the existing box
        canvas.create_rectangle(
            coords[0][0],
            coords[0][1],
            coords[2][0],
            coords[2][1],
            outline="blue",
            width=4,
            tags="existing_box",
        )

        # Draw the label inside or near the box with a white background
        label_x = (
            coords[0][0] + 5
        )  # Add a small offset to avoid overlapping with the top-left corner
        label_y = coords[0][1] + 5  # Same for the vertical positioning

        font_size = 15
        label_text = box["label"]

        # Calculate the width of the label background based on the label text length
        label_width = len(label_text) * font_size * 0.6  # Adjust based on font size
        label_height = font_size + 5  # Height of the text box with padding

        # Draw the background rectangle (white) behind the label
        canvas.create_rectangle(
            label_x - 30,
            label_y - 20,
            label_x + label_width + 20,
            label_y + label_height,
            fill="#9ebbf7",
            outline="blue",
            tags="label_bg",
        )

        # Create the label text (black)
        canvas.create_text(
            label_x,
            label_y,
            text=label_text,
            fill="black",
            font=("Arial", font_size),
            tags="existing_label",
        )


# Function to stop the drawing mode
def stop_drawing():
    global drawing_active
    drawing_active = False
    print("Drawing stopped.")


# Function to exit the program gracefully
def exit_program(output_json, page_number):
    save_boxes_incrementally(
        boxes, output_json, page_number
    )  # Save the labels for the current page
    sys.exit()  # Exit the program


# Main function for interactive labeling
def interactive_labeling(pdf_path, output_json, page_number):
    images = convert_pdf_to_images(pdf_path)

    # Ensure that the specified page exists in the PDF
    if page_number <= len(images):
        image = images[
            page_number - 1
        ]  # Convert the 1-based page number to 0-based index
    else:
        print(f"Error: Page {page_number} does not exist in the PDF.")
        return

    # Initialize Tkinter for the GUI
    global canvas, current_box, boxes, drawing_active
    boxes = load_boxes_from_json(
        output_json, page_number
    )  # Load boxes for the specific page
    current_box = []
    drawing_active = True  # Initially, drawing mode is active

    root = Tk()
    root.title(f"Interactive Labeling - Page {page_number}")

    # Create a scrollable canvas frame
    canvas_frame = Frame(root)
    canvas_frame.pack(fill="both", expand=True)

    canvas = Canvas(canvas_frame, width=image.width, height=image.height)
    canvas.pack(side="left", fill="both", expand=True)

    # Add a scrollbar to the canvas
    scrollbar = Scrollbar(canvas_frame, orient="vertical", command=canvas.yview)
    scrollbar.pack(side="right", fill="y")
    canvas.configure(yscrollcommand=scrollbar.set)

    # Display the image on the canvas
    display_image(image)

    # Draw existing boxes from the loaded JSON for the current page
    draw_existing_boxes(boxes)

    # Bind mouse events for drawing boxes only if drawing is active
    def start_draw_conditional(event):
        if drawing_active:
            start_draw(event)

    def update_draw_conditional(event):
        if drawing_active:
            update_draw(event)

    def finish_draw_conditional(event):
        if drawing_active:
            finish_draw(event, page_number)  # Pass page_number to finish_draw

    canvas.bind("<ButtonPress-1>", start_draw_conditional)
    canvas.bind("<B1-Motion>", update_draw_conditional)
    canvas.bind("<ButtonRelease-1>", finish_draw_conditional)

    # Frame to hold the buttons
    button_frame = Frame(root)
    button_frame.pack(side="bottom", fill="x", pady=10)

    # Add Save button
    save_button = Button(
        button_frame,
        text="Save Labels",
        command=lambda: save_boxes_incrementally(boxes, output_json, page_number),
    )
    save_button.pack(side="left", padx=10)

    # Add Finish button to stop drawing
    finish_button = Button(button_frame, text="Finish Drawing", command=stop_drawing)
    finish_button.pack(side="left", padx=10)

    # Add Exit button to quit the program
    exit_button = Button(
        button_frame,
        text="Exit",
        command=lambda: exit_program(output_json, page_number),
    )
    exit_button.pack(side="right", padx=10)

    # Run the Tkinter event loop
    root.mainloop()


# Run the script
if __name__ == "__main__":
    args = parse_args()
    output_json = args.output_json  # Get output JSON from command-line argument
    page_number = args.page  # Get the page number from the command-line argument
    interactive_labeling(args.pdf_path, output_json, page_number)
