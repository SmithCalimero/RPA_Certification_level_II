*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.PDF
Library             RPA.Archive
Library             OperatingSystem


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    ${orders}=    Get Orders
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        #sometimes the submit fails and since we want the robot to complete the orders even when there are occasional
        #errors on submit, so we use this keyword to retry it until it succeeds
        Wait Until Keyword Succeeds    10x    1s    Submit the order
        #the order number ensures that the file name is unique
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Wait Until Keyword Succeeds    10x    1s    Go to order another robot
    END
    Create a ZIP file of the receipts
    Cleanup
    [Teardown]    Close the browser


*** Keywords ***
Open the robot order website
    Open Available Browser    https://robotsparebinindustries.com/#/robot-order
    #Open Available Browser    https://robotsparebinindustries.com/#/robot-order    headless=True
    #the browser window will not be displayed on the screen, and the browser will run in the background, making it faster

Get orders
    #overwrite the file if it exists
    Download    https://robotsparebinindustries.com/orders.csv    overwrite=True
    #read the data from the CSV and specify that the first row is the header
    ${robot_orders}=    Read table from CSV    orders.csv    header=True
    #return the data as a list
    RETURN    ${robot_orders}

Close the annoying modal
    Wait Until Element Is Visible    css:button.btn-danger
    Click Button    css:button.btn-danger

Fill the form
    [Arguments]    ${row}
    Select From List By Value    head    ${row}[Head]
    Select Radio Button    body    ${row}[Body]
    #the input element for the leg number's id value is changing all the time so we need a more specific way to target it
    Input Text    //html/body/div/div/div[1]/div/div[1]/form/div[3]/input    ${row}[Legs]
    Input Text    address    ${row}[Address]

Preview the robot
    Click Button    Preview

Submit the order
    Click Button    Order
    Wait Until Page Contains Element    id:receipt

Store the receipt as a PDF file
    [Arguments]    ${row}
    ${receipt_html}=    Get Element Attribute    id:receipt    outerHTML
    ${order_id}=    Get Element Attribute    //html/body/div/div/div[1]/div/div[1]/div/div/p[1]    innerHTML
    #use the directory path separator variable since it is OS specific
    #/ in UNIX-like systems and \ in Windows
    Html To Pdf    ${receipt_html}    ${OUTPUT_DIR}${/}tmp/receipt_${row}.pdf
    ${pdf_details}=    Create List
    ...    ${order_id}
    ...    receipt_${row}
    #returns the system path to the pdf file
    RETURN    ${pdf_details}

Take a screenshot of the robot
    [Arguments]    ${row}
    Wait Until Page Contains Element    id:robot-preview-image
    Screenshot    id:robot-preview-image    ${OUTPUT_DIR}${/}tmp/screenshot_${row}.png
    RETURN    screenshot_${row}

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    Add Watermark Image To PDF
    ...    image_path=${OUTPUT_DIR}${/}tmp/${screenshot}.png
    ...    source_path=${OUTPUT_DIR}${/}tmp/${pdf}[1].pdf
    ...    output_path=${OUTPUT_DIR}${/}orders/${pdf}[0].pdf

Go to order another robot
    Click Button    order-another

Create a ZIP file of the receipts
    Archive Folder With Zip    ${OUTPUT_DIR}${/}orders    ${OUTPUT_DIR}${/}orders.zip

Cleanup
    #setting recursive=True specifies that the Remove Directory keyword should recursively remove all files and subdirectories within the specified directory
    #if recursive=False or not specified, the Remove Directory keyword will only remove the directory if it is empty, and will throw an error if it contains any files or subdirectories
    Remove Directory    ${OUTPUT_DIR}${/}tmp    ${True}
    Remove Directory    ${OUTPUT_DIR}${/}orders    ${True}

Close the browser
    Close Browser
