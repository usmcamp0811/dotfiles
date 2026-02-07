# Interactive PDF Labeling Tool

This tool allows you to interactively draw bounding boxes on a PDF document, label them, and save the results in a JSON file. It supports scrolling through large documents, saving the labels incrementally, and loading previously saved labels.

## Features:

- **Draw Bounding Boxes:** Click and drag to draw bounding boxes on a PDF page.
- **Label Boxes:** After drawing a box, label it with custom text.
- **Save Labels Incrementally:** Labels are saved to the specified JSON file as you go.
- **Load Existing Labels:** If a JSON file exists, previously saved bounding boxes and labels are automatically loaded and displayed.
- **Exit Gracefully:** Save all data before exiting the tool.

## Requirements:

- **Nix package manager** (to install and run the tool).

## Usage:

1. **Prepare the PDF and JSON File:**

   - Ensure you have a PDF document you want to label.
   - If you have existing labeled boxes, ensure you have the corresponding `output.json` file. If not, a new JSON file will be created when you start labeling.

2. **Run the Script Using Nix:**

   To run the tool using Nix, use the following command:

   ```bash
   nix run .#pdf-draw -- input.pdf output.json
   ```

   - **`input.pdf`**: Path to the PDF file you want to label.
   - **`output.json`**: Path to the JSON file where the labeled boxes will be saved. If the file exists, the boxes will be loaded and displayed.

3. **Interacting with the GUI:**

   - **Scroll through the PDF:** If the image is larger than the window, you can use the vertical scrollbar to scroll through the PDF.
   - **Draw Boxes:** Click and drag on the image to draw a bounding box.
   - **Label Boxes:** After releasing the mouse button, a dialog will pop up to allow you to input a label for the drawn box.
   - **Save Labels:** The **Save Labels** button saves the bounding boxes to the JSON file. This is done incrementally, so you don’t lose data.
   - **Finish Drawing:** The **Finish Drawing** button will stop the ability to draw new boxes.
   - **Exit:** The **Exit** button will save the current labels and exit the program.

4. **Viewing the Saved JSON:**
   The saved `output.json` file will contain the labeled bounding boxes in the following format:
   ```json
   [
     {
       "label": "Label 1",
       "polygon": [[x1, y1], [x2, y2], [x3, y3], [x4, y4]]
     },
     {
       "label": "Label 2",
       "polygon": [[x1, y1], [x2, y2], [x3, y3], [x4, y4]]
     }
   ]
   ```
   Each box is represented by its label and polygon coordinates (the four corners of the box).

## Example:

```bash
nix run .#pdf-draw -- my_document.pdf labels.json
```

- This command will:
  - Open `my_document.pdf`.
  - Display it in a scrollable window.
  - Let you draw and label boxes on the document.
  - Save the labels in `labels.json` as you go.

## Exiting the Program:

- Click **Exit** at any time to save the current labeled boxes and close the program.
