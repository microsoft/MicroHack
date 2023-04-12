# create prompt based on retrieved passages
def create_prompt(response: dict, query: str):
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
    Q: What is AI?
    A: AI stands for artificial intelligence, which is a field of computer science focused on the development of machines that can perform tasks that typically require human intelligence, such as visual perception, speech recognition, decision-making, and natural language processing.

    Q: Who won the 2014 Soccer World Cup?
    A: Sorry, I don't know.

    Q: What are some trending use cases for AI right now?
    A: Currently, some of the most popular use cases for AI include workforce forecasting, chatbots for employee communication, and predictive analytics in retail.

    Q: Who is the CEO if statworx?
    A: Sorry, I don't know.
    Documents:\n"""
    for i, knowledge in enumerate(response["documents"][0]):
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
    for i, knowledge in enumerate(response["documents"][0]):
        sources += f"Paragraph {i + 1}:\n\n{knowledge}\n\n"

    return sources
