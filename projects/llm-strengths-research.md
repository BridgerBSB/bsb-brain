---
title: LLM Strengths Research - Which AI Is Good At What
date: 2026-10-01
status: active
tags: [llm-explainer, ai-literacy, research]
---

# LLM Strengths Research - Which AI Is Good At What

What it is: sourced, plain-language strengths for each major AI assistant, for a beginner AI 101 deck aimed at baseball coaches and staff. Companion to [[llm-explainer-video]] and [[llm-explainer-video-research]].

Ground rules used: every strength has at least one source URL. No rankings. Wording is for beginners (8 words or fewer per strength).

## Date-sensitive notes (read before presenting)

- Model names change every few months (GPT-5.x, Claude Opus/Sonnet, Gemini 3.x). Talk about the PRODUCT (ChatGPT, Claude, Gemini), not the model number.
- Leaderboards (LMArena / arena.ai) reshuffle monthly. As of Sep 2026 the text board top spots were Claude models, with GPT-5.x and Gemini close behind; in April 2026 Claude and Gemini were within a few points. Do not put a "#1" claim on a slide. Source: https://arena.ai/leaderboard , https://www.swfte.com/ai/leaderboard
- Claude privacy changed: before Sep 28 2025 Anthropic did not train on consumer chats. Since then, Free/Pro/Max chats CAN be used for training unless you opt out (business/API not affected). Mollick's June 2025 "Claude does not train on your data" line is now out of date. Source: https://techcrunch.com/2025/08/28/anthropic-users-face-a-new-choice-opt-out-or-share-your-data-for-ai-training
- Ethan Mollick's guides: "pick one of Claude, Gemini, ChatGPT for serious use" (June 2025, reaffirmed Feb 2026). Copilot, DeepSeek, Grok treated as secondary options. Sources: https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide , https://www.oneusefulthing.org/p/a-guide-to-which-ai-to-use-in-the

## ChatGPT (OpenAI)

**Best known for:** the all-around everyday AI most people use

Strengths:
1. Most popular - about 900M weekly users. Source: https://technologychecker.io/blog/chatgpt-statistics , https://www.getpanto.ai/blog/chatgpt-statistics
2. Natural back-and-forth voice conversations. Source: https://openai.com/index/gpt-4o-and-more-tools-to-chatgpt-free/ , https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide (Mollick: among the two best voice modes)
3. Makes images from a text description. Source: https://openai.com/index/introducing-4o-image-generation/ , https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide ("most controllable image creation tool")

Also sourced: strong at complex analysis/statistics in the Pro tier (Mollick Feb 2026, https://www.oneusefulthing.org/p/a-guide-to-which-ai-to-use-in-the).

Watch out: personal accounts are opted in to training by default; turn off "Improve the model for everyone" under Settings > Data controls. Source: https://help.openai.com/en/articles/5722486-how-your-data-is-used-to-improve-model-performance . Fairness note: Claude consumer accounts now work the same way (see date-sensitive notes), so this is a general "check your settings" point, not a ChatGPT-only flaw.

## Claude (Anthropic)

**Best known for:** writing and coding help

Strengths:
1. Strong, natural-sounding writing. Source: https://www.oneusefulthing.org/p/a-guide-to-which-ai-to-use-in-the , https://www.mindstudio.ai/blog/chatgpt-vs-claude-vs-gemini-2026
2. Best-known tool for writing code (Claude Code). Source: https://www.oneusefulthing.org/p/a-guide-to-which-ai-to-use-in-the , https://www.eesel.ai/blog/claude-code-review
3. Reads very long documents in one go. Source: https://www.startuphub.ai/ai-news/reviews/2026/claude-ai-complete-guide-2026 , https://kersai.com/claude-vs-chatgpt-vs-gemini-for-business-2026-honest-comparison/

Also sourced: builds real Excel, Word, PowerPoint, PDF files in chat (https://www.eesel.ai/blog/claude-docs-review).

Watch out: does not make images or video. Source: https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide ("Claude lacks here"). Also: consumer chats used for training since Sep 2025 unless you opt out (see date-sensitive notes).

## Gemini (Google)

**Best known for:** working inside Google apps (Gmail, Docs, Drive)

Strengths:
1. Built into Gmail, Docs, Sheets, Drive. Source: https://knowledge.workspace.google.com/admin/generative-ai/workspace-with-gemini/google-workspace-with-gemini , https://support.google.com/gemini/answer/15229592?hl=en
2. Strong image and video creation (Nano Banana, Veo). Source: https://www.oneusefulthing.org/p/a-guide-to-which-ai-to-use-in-the , https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide ("Veo 3 is very impressive")
3. Deep Research reports, can use your own files. Source: https://blog.google/products/gemini/deep-research-workspace-app-integration/

Watch out: Mollick says the Gemini website is "much less capable" than the others as a general workspace (Feb 2026). Source: https://www.oneusefulthing.org/p/a-guide-to-which-ai-to-use-in-the

## Microsoft Copilot

**Best known for:** AI inside Word, Excel, Outlook and Teams

Strengths:
1. Drafts and summarizes in Word and Outlook. Source: https://learn.microsoft.com/en-us/microsoft-365/copilot/microsoft-365-copilot-overview , https://www.microsoft.com/en-us/microsoft-365
2. Helps build formulas and charts in Excel. Source: https://www.microsoft.com/en-us/microsoft-365 , https://www.microsoft.com/en-us/copilot/blog/2026/04/22/copilots-agentic-capabilities-in-word-excel-and-powerpoint-are-generally-available/
3. Takes Teams meeting notes and action items. Source: https://learn.microsoft.com/en-us/microsoft-365/copilot/microsoft-365-copilot-overview

Also sourced: built into Windows; offers many ChatGPT-like features (Mollick, https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide).

Watch out: hard to tell which AI model you are actually using; the Office features need a paid/work Microsoft 365 plan. Sources: https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide , https://www.microsoft.com/en-us/copilot/solutions/individuals

## DeepSeek

**Best known for:** a capable free AI model from China

Strengths:
1. Free to use, very capable. Source: https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide
2. Open model - anyone can download and run it. Source: https://api-docs.deepseek.com/news/news250120/ , https://builtin.com/artificial-intelligence/deepseek-r1
3. Strong at math, coding, step-by-step reasoning. Source: https://fireworks.ai/blog/deepseek-r1-deepdive , https://api-docs.deepseek.com/news/news250120/

Watch out (two, both well sourced):
- Your data is stored on servers in China; several EU regulators investigated and Italy blocked the app. Sources: https://www.euronews.com/next/2025/02/06/what-are-the-data-privacy-issues-plaguing-chinese-ai-deepseek-in-the-eu , https://www.techtarget.com/searchenterpriseai/tip/Does-using-DeepSeek-create-security-risks
- Avoids topics sensitive to the Chinese government (e.g., Tiananmen, Taiwan). Source: https://www.cbc.ca/news/business/deepseek-chatbot-chinese-censorship-1.7443419

Date note: the app is missing features the big three have (Mollick, June 2025).

## Grok (xAI)

**Best known for:** live, real-time info from X (Twitter) posts

Strengths:
1. Reads live X posts and trends. Source: https://www.datastudios.org/post/can-grok-access-x-posts-in-real-time-data-scope-and-update-speed , https://www.voiceflow.com/blog/grok
2. Good for breaking news and current buzz. Source: https://aitoolanalysis.com/grok-review/ , https://www.voiceflow.com/blog/grok
3. Built right into the X app. Source: https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide ("good if you are a big X user")

Watch out: tied to X posts, which can carry misinformation; in July 2025 an update made it post antisemitic content and xAI apologized. Mollick also notes xAI is not very transparent about how it works. Sources: https://www.cnn.com/2025/07/12/tech/xai-apology-antisemitic-grok-social-media-posts , https://time.com/7301206/elon-musk-antisemitic-posts-ai-chatbot-grok-response/ , https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide

## Meta Llama (brief)

**Best known for:** free open model behind Meta AI

- Powers Meta AI inside WhatsApp, Instagram, Facebook. Source: https://ai.meta.com/blog/llama-4-multimodal-intelligence/
- Open weights - free to download and run. Source: https://ai.meta.com/blog/llama-4-multimodal-intelligence/ , https://www.business-standard.com/technology/tech-news/meta-releases-open-weight-llama-4-ai-models-to-rival-deepseek-google-gemma-125040700272_1.html
- Most staff already have it on their phone (no signup). Source: https://ai.meta.com/blog/llama-4-multimodal-intelligence/

Slide-level framing: "You probably already have one - it's the Meta AI button in WhatsApp/Instagram." Not usually listed among the top assistants for serious work (absent from Mollick's main picks).

## Slide-ready summary

| Tool | Best known for | 3 strengths | Watch out |
|---|---|---|---|
| ChatGPT | Everyday all-around AI | Most popular; natural voice chats; makes images | Chats used for training unless you opt out (Claude too now) |
| Claude | Writing and coding | Natural writing; best-known coding tool; reads long docs | No image/video making |
| Gemini | Inside Google apps | Gmail/Docs/Drive built in; images and video; Deep Research | Website less capable (Mollick) |
| Copilot | Inside Word/Excel/Teams | Drafts in Word/Outlook; Excel formulas/charts; meeting notes | Office features need paid plan |
| DeepSeek | Free capable model from China | Free; open download; math/coding reasoning | Data stored in China; censors topics |
| Grok | Live X (Twitter) info | Live X posts; breaking news; built into X | X misinformation; July 2025 incident |
| Meta Llama | Meta AI in WhatsApp/IG | Already on your phone; free open model | Not a top pick for serious work |
