import socket
import json
import os
import subprocess

# Directory to store conversation history files
CONVERSATION_DIR = "conversation_histories"

# Ensure the directory exists
os.makedirs(CONVERSATION_DIR, exist_ok=True)

# Store conversation context per client and topic
conversation_contexts = {}

def start_udp_server():
    udp_ip = "10.0.0.70"  # Your server's IP address
    udp_port = 8765
    buffer_size = 1024

    # Create a UDP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((udp_ip, udp_port))

    print(f"UDP server is running on {udp_ip}:{udp_port}")

    while True:
        data, addr = sock.recvfrom(buffer_size)
        message = data.decode()
        print(f"Received message: {message} from {addr}")

        # Check if the message is valid JSON
        try:
            message_json = json.loads(message)
            topic = message_json.get('topic')
            content = message_json.get('content')

            if not topic or not content:
                print(f"Invalid message format: {message}")
                sock.sendto(b"Error: Invalid message format", addr)
                continue

        except json.JSONDecodeError as e:
            print(f"Failed to decode JSON: {e}")
            # Send an error response back to the client
            sock.sendto(b"Error: Invalid JSON format", addr)
            continue

        # Handle the message and generate a response
        response_text = handle_message(topic, content, addr)

        # Send the response back to the client
        if response_text:
            sock.sendto(response_text.encode(), addr)

def handle_message(topic, message, client_address):
    model_name = "llama3.1"
    api_url = "http://localhost:11434/api/chat"

    # Convert client address to a string to use as a file name
    client_id = f"{client_address[0]}_{client_address[1]}_{topic.replace(' ', '_')}"
    json_file_path = os.path.join(CONVERSATION_DIR, f"{client_id}.json")

    # Load existing conversation context from file if it exists
    if os.path.exists(json_file_path):
        with open(json_file_path, "r") as json_file:
            conversation_contexts[client_id] = json.load(json_file)
    else:
        conversation_contexts[client_id] = []

    # Append the new user message to the conversation context
    conversation_contexts[client_id].append({
        "role": "user",
        "content": message
    })

    # Prepare the data including the entire conversation context (excluding topic)
    data = {
        "model": model_name,
        "messages": conversation_contexts[client_id],
        "stream": False  # Add the "stream" field as in your successful test
    }

    json_data = json.dumps(data)

    # Prepare the curl command string
    curl_command = [
        "curl",
        api_url,
        "-d", json_data,
        "-H", "Content-Type: application/json"
    ]

    # Print the curl command for debugging
    print(f"Executing command: {curl_command}")

    try:
        # Execute the curl command using subprocess to capture stdout and stderr
        result = subprocess.run(curl_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        # Print the raw output for debugging purposes
        print(f"Raw curl output: {result.stdout}")
        print(f"Curl command error (if any): {result.stderr}")

        if result.returncode != 0:
            return f"Error executing curl command: {result.stderr}"

        # Attempt to parse the JSON response
        result_json = json.loads(result.stdout)
        response_message = result_json.get('message', {}).get('content', 'No response received')

        # Append the assistant's response to the conversation context
        conversation_contexts[client_id].append({
            "role": "assistant",
            "content": response_message
        })

        # Save the updated conversation context back to the file
        with open(json_file_path, "w") as json_file:
            json.dump(conversation_contexts[client_id], json_file, indent=4)

    except json.JSONDecodeError as e:
        # Handle JSON parsing errors
        response_message = f"Failed to decode JSON: {str(e)}"
    except Exception as e:
        # Handle general errors with curl command execution
        response_message = f"Error executing curl command: {str(e)}"
    
    return response_message

if __name__ == "__main__":
    start_udp_server()
