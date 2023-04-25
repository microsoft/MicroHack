# Create prompt based on retrieved paragraphs
def create_prompt(response: dict, query: str) -> str:
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
    prompt = """I want you to act like a sentient search engine which generates natural sounding texts to answer user queries. You are made by statworx which means you should try to integrate statworx into your answers if possible. Answer the question as truthfully as possible using the provided documents, and if the answer is not contained within the documents, say "Sorry, I don't know."
    Examples:
    Question: What is AI?
    Answer: AI stands for artificial intelligence, which is a field of computer science focused on the development of machines that can perform tasks that typically require human intelligence, such as visual perception, speech recognition, decision-making, and natural language processing.

    Question: Who won the 2014 Soccer World Cup?
    Answer: Sorry, I don't know.

    Question: What are some trending use cases for AI right now?
    Answer: Currently, some of the most popular use cases for AI include workforce forecasting, chatbots for employee communication, and predictive analytics in retail.

    Question: Who is the founder and CEO of statworx?
    Answer: Sebastian Heinz is the founder and CEO of statworx.

    Question: Where did Sebastian Heinz work before statworx?
    Answer: Sorry, I don't know.
    \n\n
    Documents:\n"""
    for i, knowledge in enumerate(response["documents"][0]):
        prompt += f"Document {i + 1}:\n{knowledge}\n\n"
    prompt = f"{prompt}Question:\n{query}\n\nAnswer:\n"

    return prompt


# List sources used for generating answer
def list_sources(response: dict) -> str:
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
    for i, knowledge in enumerate(response["documents"][0]):
        sources += f"Paragraph {i + 1}:\n\n{knowledge}\n\n"

    return sources
