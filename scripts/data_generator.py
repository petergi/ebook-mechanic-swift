def generate_data_prompt(input_prompt, variables, examples=None):
    """Generate test data for prompt templates"""
    
    # Extract variable names
    var_list = "\n".join([f"- {var}" for var in variables])
    
    # Build examples section
    examples_section = ""
    if examples:
        examples_section = f"\n\nHere are the example test cases provided by the user:\n{examples}\n"
    
    # Core meta prompt
    meta_prompt = f"""<Prompt Template>
{input_prompt}
</Prompt Template>

Your job is to construct a test case for the prompt template above. This template contains "variables", which are placeholders to be filled in later. In this case, the variables are:

<variables>
{var_list}
</variables>
{examples_section}
First, in <planning> tags, do the following:

1. Summarize the prompt template. What is the goal of the user who created it?
2. For each variable in <variables>, carefully consider what a paradigmatic, realistic example of that variable would look like. You'll want to note who will be responsible "in prod" for supplying values. Written by a human "end user"? Downloaded from a website? Extracted from a database? Think about things like length, format, and tone in addition to semantic content. Use the examples provided by the user to guide this exercise. The goal is to acquire a sense of the statistical distribution the examples are being drawn from. The example you write should be drawn from that same distribution, but sufficiently different from the examples that it provides additional signal.

Once you're done, output a test case for this prompt template with a full, complete, value for each variable. The output format should consist of a tagged block for each variable, with the value inside the block, like the below:

<planning>
1. Summary of the prompt template:
[Summary of the prompt template]
2. Consideration of variables:
[Describe what a paradigmatic, realistic example of that variables would look like]
</planning>

Output Format:
<variables>
{generate_variable_blocks(variables)}
</variables>"""
    
    return meta_prompt

def generate_variable_blocks(variables):
    """Generate XML blocks for each variable"""
    blocks = []
    for var in variables:
        blocks.append(f"<{var}>\n[a full, complete, value for the variable \"{var}\". (You do not need to repeat the variable name inside the tags.)]\n</{var}>")
    return "\n".join(blocks)

# Example usage
if __name__ == "__main__":
    variables = ["user_query", "context", "tone"]
    examples = "Example 1: user_query='How do I bake bread?', context='cooking tutorial', tone='friendly'"

    prompt = generate_data_prompt(
        input_prompt="Answer the user's question: {{user_query}} using this context: {{context}} in a {{tone}} manner.",
        variables=variables,
        examples=examples
    )
    
    print(prompt)
