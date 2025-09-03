# Llama 3.1 Summarizer for Knowledge Management

This project aims to fine-tune a Llama 3.1 8B-Instruct model to serve as a specialized "Summarizer AI." The goal is to create a model that can automatically process raw transcripts from meetings, podcasts, and videos to generate structured, interconnected knowledge summaries in Obsidian-flavored Markdown.

This is the foundational component of a larger automated knowledge management pipeline.

## Current Status

**Phase 1: Training Data Development is complete.**

The project has a high-quality, cleaned training dataset located at `training_data_cleaned.json`. This dataset has been validated and standardized by the `clean_training_data.py` script.

The next step is **Phase 2: Environment & Model Preparation**, which will take place in the `LlamaOnTPUs.ipynb` Kaggle notebook.

## Key Files
- `LlamaOnTPUs.ipynb`: The Kaggle notebook for setting up the environment and running the fine-tuning process on TPUs.
- `training_data_cleaned.json`: The final, cleaned dataset containing 2,572 examples for fine-tuning.
- `clean_training_data.py`: The Python script used to validate and standardize the raw training data.
- `training_data.json`: The original, raw training data.
