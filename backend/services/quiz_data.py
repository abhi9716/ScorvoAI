QUIZ_QUESTIONS = [
    {
        "id": 1,
        "subject": "Quantitative Aptitude",
        "chapter": "Speed & Distance",
        "question": "A train 150 m long passes a pole in 15 seconds. What is the speed of the train in km/hr?",
        "options": ["36 km/hr", "54 km/hr", "72 km/hr", "45 km/hr"],
        "correct": 0
    },
    {
        "id": 2,
        "subject": "General Knowledge",
        "chapter": "Indian Constitution",
        "question": "Who wrote the Indian Constitution?",
        "options": ["Jawaharlal Nehru", "B.R. Ambedkar", "Mahatma Gandhi", "Sardar Patel"],
        "correct": 1
    },
    {
        "id": 3,
        "subject": "Reasoning",
        "chapter": "Coding-Decoding",
        "question": "If in a certain code language, CAT is written as DBU, how will DOG be written?",
        "options": ["EPH", "FQI", "DPH", "EQH"],
        "correct": 0
    },
    {
        "id": 4,
        "subject": "Quantitative Aptitude",
        "chapter": "Average",
        "question": "The average of first 50 natural numbers is?",
        "options": ["25", "25.5", "26", "24.5"],
        "correct": 1
    },
    {
        "id": 5,
        "subject": "General Knowledge",
        "chapter": "Geography",
        "question": "Which is the longest river in India?",
        "options": ["Yamuna", "Godavari", "Ganga", "Brahmaputra"],
        "correct": 2
    },
    {
        "id": 6,
        "subject": "Quantitative Aptitude",
        "chapter": "Profit & Loss",
        "question": "A man buys an article for ₹200 and sells it for ₹250. What is his gain percent?",
        "options": ["20%", "25%", "30%", "15%"],
        "correct": 1
    },
    {
        "id": 7,
        "subject": "Reasoning",
        "chapter": "Number Series",
        "question": "Find the missing number: 2, 6, 12, 20, ?",
        "options": ["28", "30", "32", "36"],
        "correct": 1
    },
    {
        "id": 8,
        "subject": "General Knowledge",
        "chapter": "Polity",
        "question": "The Panchayati Raj system was introduced in India in which year?",
        "options": ["1950", "1959", "1965", "1947"],
        "correct": 1
    },
    {
        "id": 9,
        "subject": "Quantitative Aptitude",
        "chapter": "Percentage",
        "question": "If 30% of a number is 120, what is the number?",
        "options": ["360", "400", "450", "300"],
        "correct": 1
    },
    {
        "id": 10,
        "subject": "Reasoning",
        "chapter": "Blood Relations",
        "question": "A is the brother of B. C is the father of A. D is the brother of E. E is the daughter of B. Who is the uncle of D?",
        "options": ["A", "B", "C", "E"],
        "correct": 0
    },
    {
        "id": 11,
        "subject": "General Knowledge",
        "chapter": "Indian Constitution",
        "question": "Which Article of the Indian Constitution deals with Fundamental Rights?",
        "options": ["Article 10-25", "Article 12-35", "Article 20-40", "Article 15-30"],
        "correct": 1
    },
    {
        "id": 12,
        "subject": "Quantitative Aptitude",
        "chapter": "Ratio & Proportion",
        "question": "Two numbers are in the ratio 3:5. If their sum is 80, what is the larger number?",
        "options": ["30", "40", "50", "60"],
        "correct": 2
    },
    {
        "id": 13,
        "subject": "Reasoning",
        "chapter": "Direction Sense",
        "question": "If South-East becomes North, North-East becomes West, and so on, what will West become?",
        "options": ["North-East", "South-East", "South-West", "North-West"],
        "correct": 1
    },
    {
        "id": 14,
        "subject": "General Knowledge",
        "chapter": "Economy",
        "question": "The first Five Year Plan in India was launched in which year?",
        "options": ["1947", "1950", "1951", "1956"],
        "correct": 2
    },
    {
        "id": 15,
        "subject": "Quantitative Aptitude",
        "chapter": "Time & Work",
        "question": "A can do a piece of work in 10 days and B in 15 days. How long will they take together?",
        "options": ["5 days", "6 days", "7 days", "8 days"],
        "correct": 1
    }
]

SUBJECTS = {
    # ── Core (all exams) ──────────────────────────────────────────────────────
    "Quantitative Aptitude": [
        "Number System", "Simplification", "HCF & LCM", "Ratio & Proportion",
        "Percentage", "Profit & Loss", "Discount", "Average", "Mixture & Alligation",
        "Time & Work", "Pipes & Cisterns", "Speed & Distance", "Trains",
        "Boats & Streams", "Simple Interest", "Compound Interest",
        "Mensuration", "Geometry", "Trigonometry", "Algebra",
        "Data Interpretation", "Squares & Cube Roots", "Surds & Indices",
    ],
    "English Language": [
        "Reading Comprehension", "Synonyms & Antonyms", "Fill in the Blanks",
        "Error Spotting", "Sentence Improvement", "Cloze Test", "Para Jumbles",
        "Idioms & Phrases", "One Word Substitution", "Active & Passive Voice",
        "Direct & Indirect Speech", "Spelling Correction", "Sentence Completion",
        "Phrase Replacement", "Word Usage",
    ],
    "General Intelligence & Reasoning": [
        "Analogies", "Coding-Decoding", "Blood Relations", "Direction Sense",
        "Number Series", "Letter Series", "Odd One Out", "Syllogism",
        "Venn Diagrams", "Statement & Conclusions", "Missing Numbers",
        "Ranking & Order", "Puzzles", "Seating Arrangement",
        "Calendar Problems", "Clock Problems", "Matrix Questions",
        "Paper Folding", "Mirror & Water Images",
    ],
    # ── General Awareness (SSC / Railway / Banking) ───────────────────────────
    "General Awareness": [
        "Indian History", "World History", "Indian Geography", "World Geography",
        "Indian Polity", "Indian Constitution", "Indian Economy", "Current Affairs",
        "Science & Technology", "Sports & Games", "Books & Authors",
        "Awards & Honours", "Important Days & Events", "Static GK",
        "International Organizations", "Famous Personalities",
    ],
    # ── UPSC specific ─────────────────────────────────────────────────────────
    "History": [
        "Ancient India", "Medieval India", "Modern India", "World History",
        "Indian Art & Culture", "Freedom Movement", "Post-Independence India",
        "Mauryan Empire", "Mughal Empire", "Maratha Empire", "Vedic Period",
        "Indus Valley Civilization",
    ],
    "Geography": [
        "Physical Geography", "Indian Geography", "World Geography",
        "Climate & Monsoon", "Rivers & Lakes", "Soil & Agriculture",
        "Industries & Urbanization", "Transport & Communication",
        "Natural Resources", "Disasters & Hazards",
    ],
    "Indian Polity": [
        "Indian Constitution", "Fundamental Rights & Duties",
        "Directive Principles", "Parliament", "President & Vice President",
        "Governor & State Executive", "Judiciary & Supreme Court",
        "Local Government & Panchayati Raj", "Elections & ECI",
        "Constitutional Amendments", "Emergency Provisions",
        "Constitutional Bodies", "Centre-State Relations",
    ],
    "Indian Economy": [
        "National Income & GDP", "Five Year Plans & NITI Aayog",
        "Agriculture & Green Revolution", "Industrial Policy",
        "Foreign Trade & Balance of Payments", "Banking & RBI",
        "Government Schemes & Welfare", "Inflation & Price Index",
        "Budget & Fiscal Policy", "GST & Taxation", "Capital Markets & SEBI",
        "Poverty & Unemployment", "Economic Reforms 1991",
    ],
    "Environment & Ecology": [
        "Ecosystem & Food Chain", "Biodiversity & Conservation",
        "Climate Change & Global Warming", "Pollution Types & Control",
        "Wildlife Protection Acts", "Forest Conservation",
        "International Environmental Agreements", "Biosphere Reserves",
        "Wetlands & Ramsar Sites", "Ozone Depletion",
    ],
    "Science & Technology": [
        "Physics Concepts", "Chemistry Concepts", "Biology & Life Sciences",
        "Space Technology & ISRO", "Defense Technology",
        "IT & Computers", "Health & Medicine", "Energy Resources",
        "Biotechnology", "Nanotechnology", "Nuclear Technology",
    ],
    "Ethics & Integrity": [
        "Ethics in Public Administration", "Emotional Intelligence",
        "Values & Attitudes", "Case Studies in Ethics",
        "Moral Philosophers & Thinkers", "Integrity & Accountability",
        "Transparency & RTI", "Conflict of Interest",
    ],
    # ── Banking specific ──────────────────────────────────────────────────────
    "Banking Awareness": [
        "RBI & Monetary Policy", "Banking Regulations & Acts",
        "Types of Banks & NBFCs", "Financial Instruments & Products",
        "Credit & Loans", "Digital Banking & UPI",
        "Basel Norms", "NPA & Bad Loans", "SEBI & Capital Markets",
        "Insurance Basics & IRDAI", "NABARD & Rural Banking",
        "Priority Sector Lending", "Banking Terminology",
    ],
    "Computer Knowledge": [
        "Computer Fundamentals", "MS Office (Word, Excel, PowerPoint)",
        "Internet & Networking", "Database Basics",
        "Operating Systems", "Cyber Security & Threats",
        "Programming Basics", "Software & Hardware", "Data Storage",
    ],
    "Reasoning Ability": [
        "Syllogism", "Seating Arrangement", "Puzzles",
        "Input-Output", "Data Sufficiency", "Inequalities",
        "Coding-Decoding", "Blood Relations", "Direction Sense",
        "Ordering & Ranking", "Logical Reasoning", "Alpha-Numeric Series",
        "Coded Inequalities",
    ],
    # ── Railway specific ──────────────────────────────────────────────────────
    "General Science": [
        "Physics in Daily Life", "Chemical Reactions & Equations",
        "Human Body Systems", "Plant Biology", "Diseases & Health",
        "Nutrition & Vitamins", "Motion & Forces", "Electricity & Magnetism",
        "Heat & Thermodynamics", "Sound & Light", "Atomic Structure",
    ],
    # ── State PCS ─────────────────────────────────────────────────────────────
    "State General Knowledge": [
        "State History & Culture", "State Geography & Rivers",
        "State Economy & Industries", "State Government & Administration",
        "State Culture & Traditions", "State Current Affairs",
        "State Famous Personalities", "State Wildlife & Parks",
    ],
    "Current Affairs": [
        "National News", "International News", "Sports Events",
        "Government Schemes", "Science & Tech Developments",
        "Economic News", "Appointments & Resignations",
        "Awards & Recognitions", "Summits & Conferences",
    ],
}

DAILY_QUESTIONS = [
    {
        "id": 101,
        "subject": "Quantitative Aptitude",
        "chapter": "Percentage",
        "question": "What is 15% of 240?",
        "options": ["32", "36", "38", "34"],
        "correct": 1
    },
    {
        "id": 102,
        "subject": "General Knowledge",
        "chapter": "Geography",
        "question": "Which planet is known as the Red Planet?",
        "options": ["Venus", "Jupiter", "Mars", "Saturn"],
        "correct": 2
    },
    {
        "id": 103,
        "subject": "Reasoning",
        "chapter": "Number Series",
        "question": "Complete the series: 1, 4, 9, 16, ?",
        "options": ["20", "22", "25", "30"],
        "correct": 2
    },
    {
        "id": 104,
        "subject": "Quantitative Aptitude",
        "chapter": "Simple Interest",
        "question": "The simple interest on ₹5000 at 8% per annum for 2 years is?",
        "options": ["₹600", "₹700", "₹800", "₹900"],
        "correct": 2
    },
    {
        "id": 105,
        "subject": "General Knowledge",
        "chapter": "Polity",
        "question": "Who was the first President of India?",
        "options": ["Dr. Rajendra Prasad", "Jawaharlal Nehru", "Sardar Patel", "Dr. Radhakrishnan"],
        "correct": 0
    }
]
