# create prompt based on retrieved passages
def create_prompt(response: dict,
                query: str):
    """
    Constructs a prompt to be used as input for the OpenAI completion endpoint based on the response from vector document search.

    Parameters:
        response : dict
            A dictionary containing the response from a previous vector search. The response should have a 'documents' key that
            contains a list of strings representing the documents to use for the prompt.
        query : str
            The query for which to generate a prompt.

    Returns:
        prompt: str
            The prompt string to be used as input for the OpenAI completion endpoint.
    """
    prompt = "Answer the question based on the information contained in the documents listed below. Answer 'I don't know' if none of the documents contain any information relevant to the query.\n\n"
    for i, knowledge in enumerate(response['documents'][0]):
        prompt += f"Document {i + 1}:\n{knowledge}\n\n"
    prompt = f"{prompt}Question:\n{query}\n\nAnswer:\n"

    return prompt

# list sources used for generating answer
def list_sources(response: dict):
    """
    Constructs a string listing the sources used for generating the bot's answer.

    Parameters:
        response : dict
            A dictionary containing the response from the previous vector search. The response should have a 'documents' key that
            contains a list of strings representing the sources used for the answer.

    Returns:
        sources: str
            A string listing the sources used for the query, formatted as follows:
            "Paragraph 1: <source 1>\n\nParagraph 2: <source 2>\n\n..."
    """
    sources = ""
    for i, knowledge in enumerate(response['documents'][0]):
        sources += f"Paragraph {i + 1}:\n\n{knowledge}\n\n"

    return sources