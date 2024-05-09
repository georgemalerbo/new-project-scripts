#!/bin/bash

# Color Variables
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
NC=$(tput sgr0)

clear

printf "${BLUE}Welcome to the Node and Flask project creator!${NC}\\n"

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

prompt_yes_no "Do you want to use TypeScript?" use_typescript
prompt_yes_no "Is this a Flask application?" use_flask

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

# Initialize npm and install dependencies
if command -v npm &> /dev/null; then
    npm init -y
    printf "${GREEN}✅ npm initialized successfully with a package.json file${NC}\\n"
    npm install --save-dev css-loader html-webpack-plugin style-loader webpack webpack-cli webpack-dev-server
    printf "${GREEN}✅ Common development dependencies installed successfully.${NC}\\n"
    if [ "$use_typescript" = true ]; then
        npm install --save-dev ts-loader typescript
        printf "${GREEN}✅ TypeScript dependencies installed successfully.${NC}\\n"
    fi
else
    printf "${RED}npm is not installed. Please install npm and rerun the script.${NC}\\n"
    exit 1
fi

# Installation of additional npm packages
echo -e "${BLUE}Installing additional npm packages...${NC}"

while true; do
    # Prompt the user for additional packages or the option to exit
    read -p "${YELLOW}Enter the name of an additional npm package to install (or 'quit' to finish): ${NC}" package_name

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

    # Check if the package exists on npm registry using the npm view command
    if npm view "$package_name" --json &> /dev/null; then
        # Validate and install the package
        if npm list "$package_name" &> /dev/null; then
            echo -e "${RED}The package '$package_name' is already installed.${NC}"
        else
            echo -e "${GREEN}The package '$package_name' is available on npm registry.${NC}"

            # Extract and display package information using npm view command
            package_info=$(npm view "$package_name" --json)
            package_url="https://www.npmjs.com/package/$package_name"
            homepage_url=$(echo "$package_info" | jq -r '.homepage')

            echo -e "${BLUE}Package URL:${NC} $package_url"
            echo -e "${BLUE}Homepage URL:${NC} $homepage_url"

            # Use prompt_yes_no for installation confirmation
            install_choice=""
            prompt_yes_no "Do you want to install '$package_name'?" install_choice
            if [ "$install_choice" = true ]; then
                if npm install "$package_name"; then
                    echo -e "${GREEN}✅ Package '$package_name' installed successfully.${NC}"
                else
                    echo -e "${RED}❌ Failed to install '$package_name'.${NC}"
                fi
            else
                echo -e "${YELLOW}Installation of '$package_name' skipped.${NC}"
            fi
        fi
    else
        echo -e "${RED}The package '$package_name' is not a valid npm package or could not be found on npm registry.${NC}"
    fi
done

# Update package.json and package-lock.json after additional packages installation
npm install

echo -e "${GREEN}Final list of installed npm packages:${NC}"
npm list --depth=0

# Add build and start scripts to package.json
echo -e "${BLUE}Configuring npm scripts...${NC}"
if command -v jq &> /dev/null; then
    jq '.scripts += {"build": "webpack build --mode=production", "start": "webpack serve --mode=development --open", "dev": "webpack build --mode=development"}' package.json > temp.json && mv temp.json package.json
    printf "${GREEN}Build and start scripts added to package.json${NC}\\n"
else
    printf "${YELLOW}Warning: 'jq' is not installed. Unable to automatically insert npm scripts into package.json.${NC}\\n"
    printf "${YELLOW}Please manually add the following scripts to your package.json file:${NC}\\n"
    cat <<EOF
{
  "scripts": {
    "build": "webpack build --mode=production",
    "start": "webpack serve --mode=development --open",
    "dev": "webpack build --mode=development"
  }
}
EOF
fi

setup_flask_env() {
    echo -e "${BLUE}Creating a Python virtual environment and installing Flask...${NC}"
    python -m venv "$projectDir/venv"

    # Activate virtual environment
    if [ -f "$projectDir/venv/Scripts/activate" ]; then
        source "$projectDir/venv/Scripts/activate"
    elif [ -f "$projectDir/venv/bin/activate" ]; then
        source "$projectDir/venv/bin/activate"
    else
        echo "Could not find the virtual environment activation script."
    fi

    # Disable pip version check for all pip commands
    export PIP_DISABLE_PIP_VERSION_CHECK=1

    # Install Flask
    pip install flask
    echo -e "${GREEN}✅ Flask installed successfully.${NC}"

    # Create a requirements.txt file
    pip freeze > "$projectDir/requirements.txt"
    echo -e "${GREEN}requirements.txt created. Your Flask environment is ready!${NC}"

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


# Start of Flask setup
if [ "$use_flask" = true ]; then
    echo -e "${BLUE}Setting up directories for your Flask application...${NC}"
    mkdir -p "$projectDir/backend" "$projectDir/frontend/src" "$projectDir/frontend/src/assets" "$projectDir/frontend/dist"

    if command -v pyenv &> /dev/null; then
        echo -e "${GREEN}pyenv is detected. Proceeding with pyenv setup...${NC}"

        latest_python=$(pyenv install --list | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d '[:space:]')
        echo -e "${BLUE}The most recent stable Python version is: $latest_python${NC}"

        current_global_python=$(pyenv global)
        echo -e "${BLUE}Your current global Python version is: $current_global_python${NC}"

        use_current_python=false
        prompt_yes_no "Would you like to use the current global Python version ($current_global_python) for your Flask project? Enter 'yes' to use it, or 'no' to specify a different version." use_current_python

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

        pyenv local "$python_version"
        setup_flask_env
    else
        echo -e "${YELLOW}pyenv is not installed. Falling back to the default system Python environment.${NC}"
        setup_flask_env
    fi

    # Backend app.py
    cat <<EOT > "$projectDir/backend/app.py"
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def index():
    return "Welcome to the Simple App"

@app.route('/api/hello', methods=['GET'])
def hello_world():
    return jsonify(message="Hello World")

if __name__ == '__main__':
    app.run(debug=True)
EOT
    echo -e "${GREEN}✅ Backend app.py created.${NC}"
fi


# Determine the file extension for the entry point
file_ext="js"
if [ "$use_typescript" = true ]; then
    file_ext="ts"
fi

# tsconfig.json setup
if [ "$use_typescript" = true ]; then
    cat <<EOT > "$projectDir/tsconfig.json"
{
    "compilerOptions": {
        "target": "ES6",
        "module": "ES6",
        "rootDir": "./$(if [ "$use_flask" = true ]; then echo 'frontend/src'; else echo 'src'; fi)",
        "sourceMap": true,
        "outDir": "./$(if [ "$use_flask" = true ]; then echo 'frontend/dist'; else echo 'dist'; fi)",
        "removeComments": true,
        "noEmitOnError": true,
        "esModuleInterop": true,
        "forceConsistentCasingInFileNames": true,
        "strict": true,
        "skipLibCheck": true
    }
}
EOT
    echo -e "${GREEN}✅ tsconfig.json created.${NC}"
fi

# Determine if Flask is used and set directory paths
if [ "$use_flask" = true ]; then
    frontend_dir="$projectDir/frontend"
    mkdir -p "$frontend_dir/src"
    mkdir -p "$frontend_dir/src/assets" "$frontend_dir/dist"
else
    frontend_dir="$projectDir"
    mkdir -p "$frontend_dir/src" "$frontend_dir/dist"
fi


# Create the frontend files
cat <<EOT > "$frontend_dir/src/index.$file_ext"
// index.$file_ext
import './index.css';

$(if [ "$use_flask" = true ]; then
    if [ "$use_typescript" = true ]; then
        cat <<EOF
// Get DOM elements
const testButton = document.getElementById("testButton") as HTMLButtonElement;
const messageElement = document.getElementById("message") as HTMLElement;

// Ensure elements are not null
if (!testButton || !messageElement) {
    throw new Error("Required DOM elements not found");
}

// Event listeners
document.addEventListener("DOMContentLoaded", () => {
    testButton.addEventListener("click", () => {
        fetchHelloMessage();
    });
});

// Fetch Hello Message
async function fetchHelloMessage(): Promise<void> {
    try {
        const response = await fetch("/api/hello");

        if (!response.ok) {
            throw new Error("Server responded with an error: " + response.statusText);
        }

        const data = await response.json();
        messageElement.textContent = data.message;
    } catch (error) {
        console.error("Error fetching message:", error);
    }
}
EOF
    else
        cat <<EOF
// Get DOM elements
const testButton = document.getElementById("testButton");
const messageElement = document.getElementById("message");

// Ensure elements are not null
if (!testButton || !messageElement) {
    throw new Error("Required DOM elements not found");
}

// Event listeners
document.addEventListener("DOMContentLoaded", () => {
    testButton.addEventListener("click", () => {
        fetchHelloMessage();
    });
});

// Fetch Hello Message
async function fetchHelloMessage() {
    try {
        const response = await fetch("/api/hello");

        if (!response.ok) {
            throw new Error("Server responded with an error: " + response.statusText);
        }

        const data = await response.json();
        messageElement.textContent = data.message;
    } catch (error) {
        console.error("Error fetching message:", error);
    }
}
EOF
    fi
else
    if [ "$use_typescript" = true ]; then
        cat <<EOF
const insertHeader = (content: string): void => {
    const header: HTMLHeadingElement = document.createElement('h1');
    header.textContent = content;
    document.body.appendChild(header);
};
insertHeader('Hello, World!');
EOF
    else
        cat <<EOF
const insertHeader = (content) => {
    const header = document.createElement('h1');
    header.textContent = content;
    document.body.appendChild(header);
};
insertHeader('Hello, World!');
EOF
    fi
fi)
EOT


# index.css
cat <<EOT > "$frontend_dir/src/index.css"
/* index.css */
h1 {
  font-family: Arial, sans-serif;
}
EOT

# index.html
cat <<EOT > "$frontend_dir/src/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$projectName</title>
</head>
<body>
$(if [ "$use_flask" = true ]; then echo '
    <button id="testButton">Test Connection</button>
    <h2 id="message">Message will be displayed here</h2>'; fi)
</body>
</html>
EOT

if [ -f "$frontend_dir/src/index.html" ]; then
    echo -e "${GREEN}✅ index.html created.${NC}"
else
    echo -e "${RED}❌ Failed to create index.html.${NC}"
fi

# webpack.config.js setup
cat <<EOT > "$projectDir/webpack.config.js"
const path = require("path");
const HtmlWebpackPlugin = require("html-webpack-plugin");

module.exports = {
  target: "web",
  entry: "./$(if [ "$use_flask" = true ]; then echo 'frontend/'; fi)src/index.$file_ext",
  mode: "development",
  devtool: "source-map",
  module: {
    rules: [
      $(if [ "$use_typescript" = true ]; then echo '{
        test: /\.tsx?$/,
        use: "ts-loader",
        exclude: /node_modules/,
      },'; fi)
      {
        test: /\.css$/,
        use: ["style-loader", "css-loader"],
      },
    ],
  },
  resolve: {
    extensions: [$(if [ "$use_typescript" = true ]; then echo '".ts", ".tsx",'; fi) ".js"],
  },
  output: {
    filename: "bundle.js",
    path: path.resolve(__dirname, "$(if [ "$use_flask" = true ]; then echo './frontend/'; fi)dist"),
    publicPath: "$(if [ "$use_flask" = true ]; then echo '/'; else echo ''; fi)",
 },$(if [ "$use_flask" = true ]; then echo '
 devServer: {
   historyApiFallback: true,
   static: {
     directory: path.join(__dirname, "dist"),
   },
   hot: true,
   port: 8080,
   proxy: [
     {
       context: ["/api"],
       target: "http://127.0.0.1:5000",
       changeOrigin: true,
     },
   ],
 },'; fi)
 plugins: [
   new HtmlWebpackPlugin({
     template: "./$(if [ "$use_flask" = true ]; then echo 'frontend/'; fi)src/index.html"
   }),
 ],
};
EOT
echo -e "${GREEN}✅ webpack.config.js created.${NC}"

# Create project_structure_guide.md
cat <<EOT > "$projectDir/project_structure_guide.md"
# $projectName

This project is a$(if [ "$use_flask" = true ]; then echo ' Flask and'; fi) Node.js$(if [ "$use_typescript" = true ]; then echo ' with TypeScript'; fi) application.

## Project Structure
$(if [ "$use_flask" = true ]; then
echo 'The project is structured into two main directories:'
echo '1. \`frontend/\` - Contains the frontend code, including HTML, CSS, and JavaScript/TypeScript files.'
echo '2. \`backend/\` - Contains the Flask backend code, including Python scripts for server-side logic.'
else
echo 'The project consists of a single \`src/\` directory that contains the source code, including HTML, CSS, and JavaScript/TypeScript files.'
fi)

## Key Files
1. **\`index.$file_ext\`**: This is the main JavaScript/TypeScript file where you can start writing your application's logic.
2. **\`index.html\`**: The main HTML file that serves as the entry point for your web application.
3. **\`index.css\`**: A stylesheet where you can define styles for your web pages.
$(if [ "$use_typescript" = true ]; then echo '4. **\`tsconfig.json\`**: Configures the TypeScript compiler with various options for your project.'; fi)
5. **\`webpack.config.js\`**: This file contains the configuration for Webpack, which helps in bundling and serving your application.

## Getting Started

Follow these steps to get your development environment set up:

1. Install project dependencies: Run \`npm install\` in your terminal to install required npm packages.
2. Start the development server: Use \`npm start\` to run your local server. This command should open your application in a web browser.

$(if [ "$use_flask" = true ]; then
echo '3. Managing the Python environment:'
echo '   - **Activate the virtual environment**: This project uses a Python virtual environment to manage dependencies. To activate it, navigate to your project directory and run:'
echo '     - On Windows: \`source venv/Scripts/activate\`'
echo '     - On Unix or MacOS: \`source venv/bin/activate\`'
echo '   - **Run the Flask app**: Once the virtual environment is activated, you can start the Flask server by running:'
echo '     \`python backend/app.py\`'
echo '   - **Deactivate the environment**: When you are finished working, type \`deactivate\` in your terminal. This will exit the virtual environment and return you to the global Python environment.'
echo '   - **Managing Python packages**:'
echo '     - To install a new package, use \`pip install package-name\` while the virtual environment is activated.'
echo '     - After installing new packages, update the \`requirements.txt\` file. This file lists all the Python packages your project depends on.'
echo '     - Run \`pip freeze > requirements.txt\` to update it. This command lists all the installed packages in the activated virtual environment and saves them to \`requirements.txt\`.'
echo '     - Remember to regularly update this file as you add or remove dependencies.'
else
echo '3. Running Webpack Commands:'
echo '   - **Development Build**: Use \`npm run dev\` to create a development build of your application.'
echo '   - **Production Build**: Run \`npm run build\` for the production-ready build.'
fi)

### Best Practices for Git Repositories

When working with Git, it's important to maintain a clean and organized repository. This includes knowing which files should be tracked and which should be ignored.

#### Files to Include:
- **Source Code**: All your JavaScript/TypeScript, HTML, and CSS files.
- **Configuration Files**: Files like \`package.json\`, \`webpack.config.js\`, and \`tsconfig.json\`.
- **Documentation**: README, LICENSE, and any other documentation files.

#### Files to Ignore:
- **Node Modules**: Always exclude the \`node_modules/\` directory. These packages can be installed by running \`npm install\` with the \`package.json\` file.
- **Python Virtual Environment**: Exclude the \`venv/\` directory. This ensures that your personal virtual environment settings are not pushed to the repository.
- **Build Artifacts**: Files generated by compilers or build tools like Webpack should not be included. Typically, this means ignoring the \`dist/\` directory.
- **Environment Files**: Any \`.env\` files or other files containing sensitive information (API keys, credentials) should be ignored.

To facilitate this, create a \`.gitignore\` file in the root of your project and list these directories and file types. This will instruct Git to ignore these files in your commits.

### Additional Information

#### Adding a Favicon
To include a favicon in your project:
1. Place the \`favicon.ico\` file in the \`./frontend/src/assets/\` directory (for Flask) or in your \`src/\` directory (for non-Flask).
2. Update the \`webpack.config.js\` file to include the following configuration within the \`plugins\` array:
  \`\`\`javascript
  new HtmlWebpackPlugin({
    template: './src/index.html',
    favicon: './src/assets/favicon.ico' // Update the path as necessary
  }),
  \`\`\`
This will ensure that your favicon is included in the build process.

### Next Steps

- **Review the Created Files**: Familiarize yourself with the structure and files of your new project.
- **Customize Your Application**: Start adding custom code in the \`index.$file_ext\` file. Implement your application logic here.
- **Manage Dependencies**: 
 - For additional npm packages, use \`npm install --save-dev <package-name>\` for development dependencies or \`npm install --save <package-name>\` for production dependencies.
 - For Flask projects, manage Python dependencies using \`pip install <package>\` and remember to update \`requirements.txt\` accordingly.

### Deployment

- To deploy your application, first build it with \`npm run build\`. This creates a \`dist/\` directory with your bundled application. Deploy the contents of this directory to your web server or hosting platform.

$(if [ "$use_flask" = true ]; then
echo '### Flask-Specific Instructions'
echo 'Ensure that the virtual environment is activated whenever you are developing or running the Flask server. This isolation helps manage dependencies and keeps your project environment clean and consistent.'
fi)
EOT
echo -e "${GREEN}✅ project_structure_guide.md file created.${NC}"

# Instructions for starting the development server
echo -e "${YELLOW}To start the development server, follow these steps:${NC}"
if [ "$use_flask" = true ]; then
   echo -e "${YELLOW}1. Activate the Python virtual environment: 'source venv/bin/activate' (Linux/MacOS) or 'source venv/Scripts/activate' (Windows)${NC}"
   echo -e "${YELLOW}2. Start the Flask backend: 'python backend/app.py'${NC}"
   echo -e "${YELLOW}3. In a new terminal, navigate to the 'frontend' directory and start the frontend server: 'cd frontend && npm start'${NC}"
else
   echo -e "${YELLOW}1. Simply run 'npm start' in the project directory.${NC}"
fi


# Function to create .gitignore file based on project type
create_gitignore() {
    echo -e "${BLUE}Creating .gitignore file...${NC}"
    cat <<EOT > "$projectDir/.gitignore"

.gitignore
project_structure_guide.md

# Node modules
node_modules/

# Build artifacts
dist/

# Environment variables
.env

$(if [ "$use_flask" = true ]; then
echo "# Python virtual environment
venv/"
fi)

$(if [ "$use_typescript" = true ]; then
echo "# TypeScript declaration files
*.d.ts"
fi)
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
    

