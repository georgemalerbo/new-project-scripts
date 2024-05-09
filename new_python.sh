#!/bin/bash

# Color Variables
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
NC=$(tput sgr0)

clear

printf "${BLUE}Welcome to the Python project creator!${NC}\\n"

# Function to prompt user for a yes/no question
prompt_yes_no() {
    local prompt=$1 var_name=$2
    local input
    while true; do
        read -p "$prompt (yes/no): " input
        case $input in
            [Yy]*) eval $var_name=true; break ;;
            [Nn]*) eval $var_name=false; break ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Function to use Python/Tkinter for folder selection
select_directory_python() {
    python -c "import tkinter as tk; from tkinter import filedialog; root = tk.Tk(); root.withdraw(); print(filedialog.askdirectory())"
}

# Try selecting directory using Python/Tkinter
if command -v python &> /dev/null && python -c "import tkinter" &> /dev/null; then
    projectPath=$(select_directory_python)
fi

# Fallback to manual entry if Python/Tkinter is not available
if [ -z "$projectPath" ]; then
    read -p "Enter the path to the project directory (default: $HOME/projects): " projectPath
    projectPath=${projectPath:-"$HOME/projects"}
fi

# Validate project name and path
while true; do
    read -p "Enter the project name: " projectName
    if [[ $projectName == *" "* ]]; then
        printf "${RED}Project name must not contain spaces. Please try again.${NC}\n"
    elif [ -d "$projectPath/$projectName" ]; then
        printf "${RED}Project already exists. Please enter a different name.${NC}\n"
    else
        break
    fi
done


projectDir="$projectPath/$projectName"
mkdir -p "$projectDir" || { printf "${RED}Failed to create project directory. Exiting.${NC}\\n"; exit 1; }

printf "${GREEN}✅ Successfully created the root project folder: $projectName in the directory: ${projectDir//\\//}.${NC}\\n"

cd "$projectDir" || { printf "${RED}Failed to navigate to project directory. Exiting.${NC}\\n"; exit 1; }

setup_python_env() {
    echo -e "${BLUE}Creating a Python virtual environment...${NC}"
    python -m venv "$projectDir/venv"

    # Activate virtual environment
    if [ -f "$projectDir/venv/Scripts/activate" ]; then
        source "$projectDir/venv/Scripts/activate"
    elif [ -f "$projectDir/venv/bin/activate" ]; then
        source "$projectDir/venv/bin/activate"
    else
        echo "Could not find the virtual environment activation script."
        return 1
    fi

    # Disable pip version check for all pip commands
    export PIP_DISABLE_PIP_VERSION_CHECK=1

    # Ask user to install Pylint, Sphinx, and PyInstaller with options
    declare -A packages=(
        ["pylint"]="code analysis"
        ["sphinx"]="documentation generation"
        ["pyinstaller"]="creating standalone executables"
    )
    for pkg in "${!packages[@]}"; do
        local install_pkg
        prompt_yes_no "${YELLOW}Do you want to install $pkg (for ${packages[$pkg]})?${NC}" install_pkg
        if $install_pkg; then
            response=$(curl -s "https://pypi.org/pypi/$pkg/json")
            if [[ "$response" != "{}" ]] && [[ "$response" != "null" ]]; then
                echo -e "${GREEN}The package '$pkg' is available on PyPI.${NC}"
                
                # Extract and display package information
                package_url=$(echo "$response" | jq -r '.info.package_url')
                documentation_url=$(echo "$response" | jq -r '.info.project_urls.Documentation // empty')
                homepage_url=$(echo "$response" | jq -r '.info.project_urls.Homepage // empty')

                echo -e "${BLUE}Package URL:${NC} $package_url"
                if [[ -n "$documentation_url" ]]; then
                    echo -e "${BLUE}Documentation:${NC} $documentation_url"
                fi
                if [[ -n "$homepage_url" ]]; then
                    echo -e "${BLUE}Homepage:${NC} $homepage_url"
                fi

                # Install the package
                if pip install $pkg; then
                    echo -e "${GREEN}✅ $pkg installed successfully.${NC}"
                else
                    echo -e "${RED}❌ Failed to install $pkg.${NC}"
                    return 1
                fi
            else
                echo -e "${RED}The package '$pkg' is not a valid pip package or could not be found on PyPI.${NC}"
            fi
        else
            echo -e "${YELLOW}Installation of $pkg skipped.${NC}"
        fi
    done

    # Create a requirements.txt file
    pip freeze > "$projectDir/requirements.txt"
    echo -e "${GREEN}requirements.txt created.${NC}"

    while true; do
        # Prompt the user for additional packages or the option to exit
        read -p "${YELLOW}Enter the name of an additional pip package to install (or 'quit' to finish): ${NC}" package_name

        # Improved exit condition
        if [[ "$package_name" =~ ^(quit|q|QUIT|Q)$ ]]; then
            echo -e "${GREEN}Exiting the package installation process.${NC}"
            break
        fi

        # Validate input is not empty and does not contain spaces
        if [[ -z "$package_name" || "$package_name" =~ \  ]]; then
            echo -e "${RED}Invalid input: Package name must not be empty and must not contain spaces. Please try again.${NC}"
            continue
        fi

        # Check if the package exists on PyPI using the JSON API
        response=$(curl -s "https://pypi.org/pypi/$package_name/json")
        if [[ "$response" != "{}" ]] && [[ "$response" != "null" ]] && echo "$response" | jq -e .info.name > /dev/null; then
            # Validate and install the package
            if pip show "$package_name" &> /dev/null; then
                echo -e "${RED}The package '$package_name' is already installed.${NC}"
            else
                echo -e "${GREEN}The package '$package_name' is available on PyPI.${NC}"

                # Extract and display package information from the JSON response
                package_url=$(echo "$response" | jq -r '.info.package_url')
                documentation_url=$(echo "$response" | jq -r '.info.project_urls.Documentation // empty')
                homepage_url=$(echo "$response" | jq -r '.info.project_urls.Homepage // empty')

                echo -e "${BLUE}Package URL:${NC} $package_url"
                if [[ -n "$documentation_url" ]]; then
                    echo -e "${BLUE}Documentation:${NC} $documentation_url"
                fi
                if [[ -n "$homepage_url" ]]; then
                    echo -e "${BLUE}Homepage:${NC} $homepage_url"
                fi

                # Use prompt_yes_no for installation confirmation
                local install_choice
                prompt_yes_no "Do you want to install '$package_name'?" install_choice
                if [ "$install_choice" = true ]; then
                    if pip install "$package_name"; then
                        echo -e "${GREEN}✅ Package '$package_name' installed successfully.${NC}"
                    else
                        echo -e "${RED}❌ Failed to install '$package_name'.${NC}"
                    fi
                else
                    echo -e "${YELLOW}Installation of '$package_name' skipped.${NC}"
                fi
            fi
        else
            echo -e "${RED}The package '$package_name' is not a valid pip package or could not be found on PyPI.${NC}"
        fi
    done

    # Update requirements.txt after additional packages installation
    pip freeze > "$projectDir/requirements.txt"
    echo -e "${GREEN}Final list of installed pip packages:${NC}"
    pip list
}



echo -e "${BLUE}Setting up directories for your Python application...${NC}"
mkdir -p "$projectDir/src" "$projectDir/docs" 

# Start of Python project setup
if command -v pyenv &> /dev/null; then
    echo -e "${GREEN}pyenv is detected. Proceeding with pyenv setup...${NC}"

    # Fetching the most recent Python version available
    latest_python=$(pyenv install --list | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d '[:space:]')
    echo -e "${BLUE}The most recent stable Python version is: $latest_python${NC}"

    # Showing the current global Python version
    current_global_python=$(pyenv global)
    echo -e "${BLUE}Your current global Python version is: $current_global_python${NC}"

    # Prompting the user to choose between the current global version and a different one
    use_current_python=false
    prompt_yes_no "Would you like to use the current global Python version ($current_global_python) for your Python project? Enter 'yes' to use it, or 'no' to specify a different version." use_current_python

    if [ "$use_current_python" = false ]; then
        valid_version=false
        while [ "$valid_version" = false ]; do
            echo -e "${BLUE}Installed Python versions:${NC}"
            pyenv versions
            read -p "Please enter one of the above Python versions or specify a new one to install (or type 'list' to display available versions): " python_version

            if [ "$python_version" = "list" ]; then
                pyenv install --list | grep -E '^\s*3\.[0-9]+\.[0-9]+$'
                continue
            fi

            if pyenv versions | grep -q " $python_version" || pyenv install --list | grep -q "^  $python_version\$"; then
                valid_version=true
                if pyenv versions | grep -q "$python_version"; then
                    echo -e "${BLUE}Using Python $python_version.${NC}"
                else
                    echo -e "${BLUE}Installing Python $python_version using pyenv...${NC}"
                    pyenv install "$python_version" || { echo "Failed to install Python $python_version"; exit 1; }
                fi
            else
                echo -e "${RED}Invalid Python version: $python_version. Please enter a valid version or type 'list' to see available versions.${NC}"
            fi
        done
    else
        python_version=$current_global_python
    fi

    # Set local Python version for the project
    pyenv local "$python_version"

    # Activate virtual environment
    setup_python_env
else
    echo -e "${YELLOW}pyenv is not installed. Falling back to the default system Python environment.${NC}"
    setup_python_env
fi


# main.py
cat <<EOT > "$projectDir/src/main.py"
"""
A simple module for demonstrating a basic Python program.
"""


def print_hello(name):
    """
    Prints "Hello" followed by the provided name.

    Args:
        name (str): The name to greet.
    """
    print(f"Hello, {name}!")


def main():
    """
    The main function that calls print_hello.
    """
    print_hello("$projectName")


if __name__ == "__main__":
    main()
EOT
echo -e "${GREEN}✅ main.py created.${NC}"
# Generate project_structure_guide.md based on selected options
cat <<EOT > "$projectDir/project_structure_guide.md"
# $projectName

Introduction to **$projectName** project. This project is structured as a standard Python application.

## Contents

- [Structure of the Project](#structure-of-the-project)
- [Principal Files](#principal-files)
- [Initial Setup](#initial-setup)
$(if [[ ${packages[pylint]+_} ]]; then echo '- [Pylint](#pylint)'; fi)
- [Type Annotations](#type-annotations)
$(if [[ ${packages[sphinx]+_} ]]; then echo '- [Sphinx](#sphinx)'; fi)
$(if [[ ${packages[pyinstaller]+_} ]]; then echo '- [PyInstaller](#pyinstaller)'; fi)
- [Cython](#cython)
- [Publishing Documentation Online](#publishing-documentation-online)
- [Configuring a Git Repository for the Project](#configuring-a-git-repository-for-the-project)

## Structure of the Project

The project's architecture is organized into several folders, each with a specific role:

- **\`src/\`**:
  - Hosts the Python source code files.
  - \`main.py\`: The core application logic.
  - Other required modules.

- **\`tests/\`**:
  - Includes unit tests for the application.

- **\`docs/\`**:
  - Contains the source files for Sphinx documentation, if installed.
  - \`conf.py\`: Configuration file for Sphinx, if installed.
  - \`index.rst\`: Primary index file for Sphinx, if installed.
  - Other essential documentation files.

## Principal Files

- **\`main.py\`**: The starting point of the application.
- **\`requirements.txt\`**: Enumerates all the dependencies of the Python package.
- **\`project_structure_guide.md\`**: The current file, offering a synopsis and setup guidelines.

## Initial Setup

To prepare your development environment, proceed as follows:

1. **Virtual Environment**:
   - Creation: \`python -m venv venv\`.
   - Activation:
     - On Windows: \`venv\\Scripts\\activate\`.
     - On Linux/MacOS: \`source venv/bin/activate\`.

2. **Dependencies**:
   - For package installation: \`pip install <package>\`.
   - To refresh \`requirements.txt\`: \`pip freeze > requirements.txt\`.
   - To verify installed packages: \`pip list\`.
   - For installing all packages in \`requirements.txt\`:
     - \`pip install -r requirements.txt\`.

3. **Customization**:
   - Modify \`src/main.py\` and additional modules as needed.
   - Incorporate unit tests in \`tests/\`.

4. **Running the Application**:
   - Execute: \`python src/main.py\`.

$(if [[ ${packages[pylint]+_} ]]; then echo "
## Pylint

Pylint is a static code analysis tool that scrutinizes Python code for potential errors and enforces a coding standard.

1. Installation of Pylint via pip:
   - \`pip install pylint\`

2. Execution of Pylint on a Python file:
   - Substitute 'your_script.py' with the actual name of your Python file.
   - \`pylint your_script.py\`
   - This command scrutinizes your file and identifies issues like style infractions and potential errors.

3. Deciphering Pylint's Output Categories:
   - Errors (E): Syntax mistakes or undefined variables.
   - Warnings (W): Code patterns that could be problematic.
   - Refactor (R): Recommendations to enhance code structure.
   - Convention (C): Stylistic discrepancies from PEP 8 or other norms.
   - Info (I): General details or minor concerns.
   - Each item in the report includes specifics and the location in your code.

4. Customization of Pylint with a .pylintrc File:
   - To comply with particular coding standards, like the Google Python Style Guide, use a tailored .pylintrc file.
   - Place the downloaded .pylintrc file in the root directory of your project.
   - Alternatively, directly specify the configuration file:
     - \`pylint --rcfile=/path/to/custom-pylintrc your_script.py\`
   - Modify the .pylintrc file to activate/deactivate specific checks as per the requirements of your project.

5. Integration of Pylint with Your IDE:
   - Install a Python plugin in your IDE.
   - Set up the plugin to utilize Pylint for live code analysis.
"; fi)

## Type Annotations

Type Annotations in Python, introduced in PEP 484, offer a structured method to explicitly declare the data types of variables, function parameters, and return values. While type annotations do not enforce type checking at runtime, they are invaluable for static analysis, improving readability, and aiding in maintaining a clean codebase.

### Understanding Type Annotations

In Python, type annotations are added using a colon (:) after variable and function parameter names, followed by the data type. For function return types, use the arrow notation (->) followed by the data type, and end the line with a colon.

Here's an example demonstrating the use of type annotations in a function definition:

\`\`\`python
def greet(name: str) -> str:
    return "Hello, " + name
\`\`\`

In this snippet, the \`greet\` function is expected to receive a string (\`str\`) as an argument and also return a string.

### Common Use Cases

1. **Function Annotations**:
   - Clearly define the types of parameters and the return type of functions.
   - Enhance code readability and clarify the function's contract.

2. **Variable Annotations**:
   - Declare the type of a variable.
   - Especially beneficial in larger codebases for maintaining consistency and clarity.

### Benefits of Type Annotations

- **Code Quality Improvement**: Annotations make the code more readable and easier to maintain.
- **Enhanced Development Experience**: Modern IDEs leverage type annotations to provide improved code completion, error detection, and automated refactoring.
- **Facilitation of Static Analysis**: Tools like Mypy utilize type annotations for static type checking, potentially catching bugs before runtime.

### Practical Tips

1. **Gradual Adoption**: It's practical to incrementally introduce type annotations in your codebase, starting with the most critical parts such as public APIs.
2. **Leverage Type Checkers**: Use static type checking tools like Mypy to analyze your codebase.
3. **No Runtime Overhead**: Type annotations are disregarded at runtime, meaning they don't introduce any performance penalty.

### Example with Complex Types

Below is an example of a function that accepts a list of integers and returns a dictionary mapping integers to their string representations, using the modern syntax introduced in Python 3.9:

\`\`\`python
def stringify_numbers(numbers: list[int]) -> dict[int, str]:
    return {number: str(number) for number in numbers}
\`\`\`

In this example, we use the built-in \`list\` and \`dict\` types with type parameters directly, reflecting modern best practices introduced in Python 3.9 and later.

$(if [[ ${packages[sphinx]+_} ]]; then echo "
## Sphinx

Sphinx is an indispensable tool for generating elegant and functional documentation for Python projects. This segment offers a step-by-step guide to incorporate Sphinx effectively.

1. Sphinx Installation: Ascertain that Sphinx is part of your environment (\`pip install sphinx\`).
2. Initiating a Project: Invoke \`sphinx-quickstart\` to establish a rudimentary project structure. This command generates initial versions of \`conf.py\` and \`index.rst\`.
   - When prompted for the option \`Separate source and build directories (y/n) [n]:\`, choose \`n\`.
   - Sphinx will then designate the \`docs/\` directory for source files and \`docs/_build/\` for build files.
   - In the \`docs/\` directory, alongside \`conf.py\` and \`index.rst\`, directories named \`_static/\`, \`_templates/\`, and \`_build/\` will be created.
   - The \`_build/\` directory will further contain subdirectories named \`doctrees/\`, \`html/\`, and \`latex/\`.

3. Personalizing \`index.rst\` and \`conf.py\`: Adapt the provided templates in these files to fit your project's specifics.

### Example \`index.rst\`

\`\`\`rst
.. Your Project's Documentation Master File, created by
   sphinx-quickstart on [date].
   You can adapt this file completely to your liking, but it should at least
   contain the root \`toctree\` directive.

.. toctree::
   :maxdepth: 2
   :caption: Contents:

Introduction
------------

This is the documentation for your project.

Module 1
--------

.. automodule:: module1
   :members:
   :undoc-members:
   :show-inheritance:

Module 2
--------

.. automodule:: module2
   :members:
   :undoc-members:
   :show-inheritance:

Class Hierarchy
---------------
.. inheritance-diagram:: module1 module2

... [additional modules and content]

Indices and tables
==================

* :ref:\`genindex\`
* :ref:\`modindex\`
* :ref:\`search\`
\`\`\`

### Example \`conf.py\`

\`\`\`python
# conf.py

# Configuration file for the Sphinx documentation builder.

# Importing necessary modules
import os
import sys
sys.path.insert(0, os.path.abspath('../src'))  # Include the project source directory in the path.

# -- Project information -----------------------------------------------------

project = 'Your Project Name'
copyright = 'Year, Your Name'
author = 'Your Name'
release = 'Version'

# -- General configuration ---------------------------------------------------

# List any Sphinx extension module names here.
extensions = [
    'sphinx.ext.autodoc',  # Auto-document from docstrings
    'sphinx.ext.viewcode',  # Include links to source code
    'sphinx.ext.coverage',  # Coverage reporting
    'sphinx.ext.napoleon',  # Support for Google and NumPy style docstrings
    'sphinx.ext.inheritance_diagram',  # Inheritance diagrams
    'sphinx.ext.graphviz',  # Graphviz support
]

# Enable module names in object descriptions
add_module_names = True

# Define the order in which autodoc lists members
autodoc_member_order = 'bysource'  # Options: 'bysource', 'groupwise', 'alphabetical'

# Paths for templates and static files
templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# -- HTML output options -------------------------------------------------

# HTML Theme settings
html_theme = 'sphinx_book_theme' 
# Note: sphinx_book_theme is not a default Sphinx theme. To install, run: pip install sphinx-book-theme
# For default themes, refer to: https://www.sphinx-doc.org/en/master/usage/theming.html

# Path for static files
html_static_path = ['_static']

# -- Graphviz configuration -------------------------------------------------

inheritance_graph_attrs = {
    rankdir="LR",  # Graph layout direction
    size='"6.0, 8.0"',  # Graph size
    fontsize=14,  # Font size for graph elements
    ratio='compress'  # Graph aspect ratio
}

inheritance_node_attrs = {
    shape='ellipse',  # Node shape
    fontsize=14,  # Font size for node text
    height=0.75,  # Node height
    color='dodgerblue1',  # Node color
    style='filled'  # Node style
}

# Output format for Graphviz graphs
graphviz_output_format = 'svg'
\`\`\`

4. Building the Documentation: Execute \`make html\` within the \`docs/\` directory. This command compiles the documentation and outputs HTML files in \`docs/_build/html/\`.
5. Local Viewing of Documentation: Open the file \`docs/_build/html/index.html\` in a browser to review your documentation locally.
6. Creating PDF Documentation: If a PDF version is required, run \`make latexpdf\` in the \`docs/\` directory. The resulting PDF file will be placed in \`docs/_build/latex/\`.
"; fi)

$(if [[ ${packages[pyinstaller]+_} ]]; then echo "
## PyInstaller

PyInstaller serves as a robust utility to transform Python applications into standalone executables, suitable for various operating systems like Windows, GNU/Linux, and macOS. It's especially beneficial for distributing Python applications to users who might not have Python installed.

### Installation of PyInstaller
1. PyInstaller is installable via pip. Use the command below in your terminal or command prompt:
   - Command: \`pip install pyinstaller\`

### Basic Usage
1. To convert your Python script into an executable, head to your project directory (where your main Python script resides).
2. Use the PyInstaller command followed by your script's filename:
   - \`pyinstaller your_script.py\`
   - This process will create a \`dist/\` directory in your project folder, where the executable version of your script will be located.

### Advanced Customization and Optimization Options
- \`--onefile\`: Consolidates your application into a single executable file for easy distribution, though it may increase the initial loading time of your application.
  - Usage: \`pyinstaller --onefile your_script.py\`
- \`--noconsole\`: Best suited for GUI applications, this option prevents a console window from appearing when your application is running.
  - Usage: \`pyinstaller --noconsole your_script.py\`
- \`--name\`: Assign a custom name to your generated executable, instead of the default script name.
  - Usage: \`pyinstaller --name="YourAppName" your_script.py\`
- \`--add-data\`: Incorporate additional data files (like images or external files) into your executable. Note that the syntax differs between Windows and Unix-based systems.
  - Windows: \`pyinstaller --add-data "src;dest" your_script.py\`
  - Unix: \`pyinstaller --add-data "src:dest" your_script.py\`
- \`--icon\`: Customize your executable's icon by specifying a path to your \`.ico\` (Windows) or \`.icns\` (macOS) file.
  - Usage: \`pyinstaller --icon=app.ico your_script.py\`
- \`--hidden-import\`: Explicitly package hidden imports that PyInstaller might not detect automatically, ensuring that all necessary modules are included.
  - Usage: \`pyinstaller --hidden-import=package_name your_script.py\`

### Practical Scenarios
1. **Portable Applications Creation**: Ideal for making your Python applications portable, allowing them to operate on any compatible system without requiring Python or setup procedures.
2. **Distribution of Commercial Software**: For proprietary or commercial software, PyInstaller streamlines the distribution process, potentially concealing the source code and making distribution more straightforward.
3. **Simplification of Deployment**: Deploying a singular executable can be simpler and less prone to errors compared to deploying an entire Python environment with numerous dependencies.

### Tips for Optimizing Your PyInstaller Experience
- **Testing in a Clean Environment**: Validate your packaged application in a pristine environment (like a new virtual machine) to ensure it operates correctly without dependencies from your development setting.
- **Attention to Warnings**: Monitor the warnings emitted by PyInstaller during the packaging process. These can provide crucial insights about missing files or other issues.
- **Dependency Management**: Employ virtual environments to manage your application's dependencies, ensuring consistency between your packaged application and your development environment.

### Troubleshooting Common Issues
- **Resolving Missing Files**: If your application fails to locate certain files at runtime, use the \`--add-data\` option to guarantee that all necessary files are bundled with your executable.
- **Addressing Library Problems**: If specific library issues arise, consult the PyInstaller Hooks repository for potential solutions or consider creating custom hook files.
- **Anti-virus Software Interactions**: Some anti-virus solutions may mistakenly flag executables generated by PyInstaller as suspicious. To counter this, test your application on intended systems and consider signing your executable with a digital certificate to affirm its legitimacy.

By adhering to these comprehensive guidelines and utilizing PyInstaller's extensive capabilities, you can effectively distribute your Python applications, ensuring a polished and user-friendly experience for your end users.
"; fi)

## Cython

This tutorial delves deeply into the use of Cython in Python projects, focusing on two distinct approaches to managing type declarations. For demonstration purposes, we'll construct a prime number generator employing Cython's unique syntax for type declarations.

#### Comprehensive File Structure for a Cython-Based Project
- \`prime.pyx\` - The Cython module that implements the prime number generator.
- \`setup.py\` - A script to compile and build the Cython module.
- \`main.py\` - A Python script to test the compiled Cython module.
- \`build/\` - A directory designated for the compiled Cython files.

#### 1. Cython Installation
- Install Cython using pip:
  - Command: \`pip install Cython\`

#### 2. Implementation of the Cython Module (\`prime.pyx\`)
- Craft a prime number generator employing Cython's optimized type declarations:
  \`\`\`cython
  # prime.pyx
  cdef int check_prime(int num):
      """Evaluate if a number is prime."""
      cdef int i
      if num < 2:
          return False
      for i in range(2, num):
          if num % i == 0:
              return False
      return True

  cpdef list create_primes(int upper_limit):
      """Craft a list of prime numbers up to a specified upper limit."""
      cdef int num
      prime_list = []  # A standard Python list to store prime numbers
      for num in range(upper_limit):
          if check_prime(num):
              prime_list.append(num)
      return prime_list
  \`\`\`
- Uses \`cdef\` for declaring types at the C level and \`cpdef\` for creating functions accessible from both C and Python.

#### 3. Compilation Script (\`setup.py\`)
- Develop a script to compile the Cython module into a Python extension:
  \`\`\`python
  # setup.py
  from setuptools import setup
  from Cython.Build import cythonize

  setup(
      name='Cython Prime Number Generator Module',
      ext_modules=cythonize("prime.pyx"),
  )
  \`\`\`
- The \`ext_modules\` parameter can include multiple Cython modules for compilation.

#### 4. Cython Code Compilation
- Compile the Cython module by executing:
  - \`python setup.py build_ext --inplace\`

#### 5. Implementation of the Python Script (\`main.py\`)
- Create a script to utilize the compiled Cython module:
  \`\`\`python
  # main.py
  from prime import create_primes

  def main():
      upper_limit = 100
      primes = create_primes(upper_limit);
      print(f"Primes up to {upper_limit}: {primes}");

  if __name__ == "__main__":
      main();
  \`\`\`

#### 6. Execution of the Project
- Compile and execute the project to validate the functionality of the Cython-based prime number generator.

### Understanding Type Declarations in Cython

#### 1. Cython-Specific Syntax (cdef, cpdef, etc.)
- \`cdef\`: Utilized for declaring C variables, types, and functions.
  \`\`\`cython
  cdef int i, j
  cdef float f
  cdef my_function(int a, char* b):
      ...
  \`\`\`
- \`cpdef\`: Generates a C function alongside a function accessible from Python.
  \`\`\`cython
  cpdef int sum(int x, int y):
      return x + y
  \`\`\`

#### 2. Utilizing Pure Python Syntax with PEP-484 and PEP-526
- Adopt Python syntax for type hints and variable annotations.
  \`\`\`python
  def sum(x: int, y: int) -> int:
      return x + y
  total: int = 0
  \`\`\`
- Ensures compatibility with Python, enhancing code readability and portability.

#### Comparison and Applications
- Cython-Specific Syntax: Optimal for intense performance optimization and integration with C.
- Pure Python Syntax: More readable and focused on Python-centric projects.

#### Examples
- Cython-Specific:
  \`\`\`cython
  cdef int sum(int x, int y):
      return x + y
  \`\`\`
- Pure Python with Type Annotations:
  \`\`\`python
  def sum(x: int, y: int) -> int:
      return x + y
  \`\`\`

This tutorial demonstrates Cython's versatility in supporting both C-like and Pythonic syntax for type declarations, empowering developers to select the most fitting approach based on their project requirements and familiarity with these languages.

## Publishing Documentation Online

1. For projects hosted on GitHub, GitHub Pages is an excellent platform for publishing your documentation.
2. Initiate a new branch named \`gh-pages\` in your repository with the command:
   - \`git checkout -b gh-pages\`
   - This command not only creates the \`gh-pages\` branch but also switches your working directory to it.
3. The \`gh-pages\` branch is a dedicated branch that GitHub Pages uses to serve your documentation, offering a neat separation from your source code.
   - The \`gh-pages\` branch will maintain its own commit history, distinct from your source code.
4. Transfer the contents of \`docs/_build/html/\` to the \`gh-pages\` branch using the following sequence of commands:
   - \`git checkout gh-pages\`
   - \`cp -r docs/_build/html/* .\`
   - \`git add .\`
   - \`git commit -m "Initial documentation commit"\`
   - \`git push origin gh-pages\`
5. On GitHub, navigate to your repository's Settings, then proceed to the GitHub Pages section.
6. Choose \`gh-pages\` as the source and confirm by clicking \`Save\`.
7. Remember, whenever your documentation is updated, you should rebuild it using \`make html\` and synchronize the hosted files to reflect these changes.
8. To revert to the \`main\` branch, use the command \`git checkout main\`.

## Configuring a Git Repository for Your Project

1. Initiate a Git repository in your project's root directory:
   - \`git init\`

2. Verify the Current Branch Name (Optional):
   - \`git branch\`

3. Local Branch Renaming:
   - \`git branch --move main\`

4. Add Your Files and Commit:
   - \`git add .\`
   - \`git commit -m "Initial project commit"\`

5. Create a New Repository on GitHub:
   - Note: This step involves creating a new repository manually on GitHub.
     - Visit GitHub and log in.
     - Click the '+' icon in the top right corner, then select 'New repository'.
     - Input the repository name (should correspond to 'my-repo' used subsequently).
     - Choose whether your repository will be 'Public' or 'Private'.
     - Skip initializing with a README, .gitignore, or license as your project already contains files.
     - Click 'Create repository'.

6. Link Your Local Repository with the Remote Repository on GitHub:
   - \`git remote add origin git@github.com:your_username/my-repo.git\`
   - Replace 'your_username' with your actual GitHub username and 'my-repo' with your repository's name.
   - This step establishes a connection between your local and remote repositories.

7. Set 'main' as the Default Branch:
   - If your Git version initializes a different default branch (like 'master'), rename it to 'main':
     - \`git branch -M main\`
   - This command renames your current branch to 'main'.

8. Upload Your Commit to GitHub:
   - \`git push -u origin main\`
   - This command uploads your 'main' branch to the remote repository.
   - The \`-u\` flag links your local branch with the remote branch.

EOT
echo -e "${GREEN}✅ project_structure_guide.md file successfully created.${NC}"





# Function to create .gitignore file based on project type
create_gitignore() {
    echo -e "${BLUE}Creating .gitignore file...${NC}"
    cat <<EOT > "$projectDir/.gitignore"
project_structure_guide.md

# Local .gitignore file
.gitignore

# IDE-specific settings
# Visual Studio Code
.vscode/

# Python virtual environment folder to exclude environment-specific configurations and libraries
venv/

# Compiled Python files that are automatically generated and not needed for version control
__pycache__/

# Python bytecode compiled dynamically (if not covered by __pycache__)
*.pyc

# Distribution packages like wheels and build artifacts typically created by setuptools
dist/
build/

# pytest cache directory for storing runtime data
.pytest_cache/

# Sphinx documentation build directory
docs/_build/

# MyPy type checking cache
.mypy_cache/

# .env files that may contain sensitive information like environment variables
.env

# Cython generated files
*.so
*.c

# PyInstaller spec files and build/output folders, if used
*.spec
pyinstaller_build/
pyinstaller_output/

# Exclude user-specific files like personal scripts or config files not part of the project
# /my_script.py
EOT
    echo -e "${GREEN}✅ .gitignore file created with relevant entries based on the project settings.${NC}"
}

# Prompt user to initialize a git repository
prompt_yes_no "Do you want to initialize a git repository for this project?" init_git

if [ "$init_git" = true ]; then
    echo -e "${BLUE}Initializing Git repository...${NC}"
    git init
    echo -e "${GREEN}✅ Git repository initialized.${NC}"

    create_gitignore  # Call the function to create .gitignore

    git add .
    git commit -m "Initial project setup"
    echo -e "${GREEN}✅ Initial commit created.${NC}"
else
    echo -e "${YELLOW}Skipping Git repository initialization.${NC}"
fi


# Open project in Visual Studio Code
prompt_yes_no "Do you want to open the project in Visual Studio Code?" open_vscode
if [ "$open_vscode" = true ] && command -v code &> /dev/null; then
    code "$projectDir"
fi

printf "${GREEN}✅ Project setup completed successfully.${NC}\\n"
