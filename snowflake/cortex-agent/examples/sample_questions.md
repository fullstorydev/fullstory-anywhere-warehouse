# Sample Questions for Fullstory Cortex Agent

This document contains 100+ example questions you can ask the Fullstory Analytics Agent.
Use these to explore your data and understand agent capabilities.

---

## Session Analytics

### Basic Metrics
1. How many unique users visited our site last week?
2. What's the total number of sessions today?
3. How many page views did we have yesterday?
4. What's the average session duration?
5. Show me daily active users for the past 30 days

### Engagement
6. What are the most viewed pages?
7. Which pages have the highest average time on page?
8. What's the average scroll depth across all pages?
9. Show me pages where users scroll less than 50%
10. Which pages have the lowest engagement rate?

### User Journey
11. How many users visited more than 5 pages per session?
12. What percentage of users are identified (logged in)?
13. Show me the top entry pages
14. Which pages do users navigate to most after the homepage?
15. What's the average number of page views per session?

---

## Performance & Core Web Vitals

### LCP (Largest Contentful Paint)
16. What's our average LCP?
17. What percentage of page loads have good LCP (under 2.5 seconds)?
18. Which pages have the worst LCP?
19. Show me LCP trends over the past month
20. Compare LCP between mobile and desktop

### CLS (Cumulative Layout Shift)
21. What's our average CLS score?
22. How many page loads have CLS above 0.1?
23. Which pages have the worst layout shift?
24. Show me pages with CLS over 0.25 (poor)

### INP (Interaction to Next Paint)
25. What's our average INP?
26. What percentage of interactions have good INP (under 200ms)?
27. Which pages have the slowest interaction response times?

### Other Performance
28. What's our average Time to First Byte (TTFB)?
29. Show me average page load time by page
30. Compare Core Web Vitals week over week
31. Which browsers have the worst performance?

---

## Frustration Signals

### Rage Clicks
32. How many rage clicks happened last week?
33. Which pages have the most rage clicks?
34. What elements are users rage clicking on?
35. Show me sessions with more than 3 rage clicks
36. What's the rage click rate by device type?

### Dead Clicks
37. How many dead clicks occurred yesterday?
38. Which pages have the most dead clicks?
39. Show me the top elements with dead clicks
40. What percentage of clicks are dead clicks?

### Other Frustration
41. How many mouse thrash events occurred?
42. Which pages trigger the most frustration?
43. Show me sessions with high frustration (rage + dead + thrash)
44. How many forms were abandoned last week?
45. Which form fields have the highest abandonment rate?

---

## Error Tracking

### JavaScript Exceptions
46. What are the top 10 JavaScript errors?
47. How many unhandled exceptions occurred last week?
48. Which pages have the most errors?
49. Show me error trends over the past month
50. How many users encountered at least one error?

### Failed Requests
51. How many 500 errors occurred today?
52. Which API endpoints are failing most?
53. Show me 4xx errors by endpoint
54. What's the average response time for failed requests?
55. Compare server errors vs client errors

### Console Messages
56. How many console errors were logged?
57. What are the most common console error messages?
58. Show me console warnings by page

---

## Conversion & Custom Events

### Conversion Tracking
59. How many checkout completions happened today?
60. What's our signup conversion rate?
61. Show me custom events by name
62. What's the conversion rate by device type?
63. Compare conversion rates week over week

### Funnel Analysis
64. How many users started checkout but didn't complete?
65. What's the drop-off rate between cart and checkout?
66. Show me the car search to booking funnel
67. Which pages have the highest exit rate?

### Feature Adoption
68. How many users triggered the experiment event?
69. Show me NPS survey completions
70. What percentage of users saw the banner?

---

## Segmentation & Comparison

### By Device
71. Compare sessions between mobile and desktop
72. What percentage of users are on mobile?
73. Show me tablet engagement metrics
74. Which device type has the highest conversion rate?

### By Browser
75. Break down sessions by browser
76. Compare Chrome vs Safari performance
77. Which browsers have the most errors?
78. Show me rage clicks by browser

### By Geography
79. What countries are our users from?
80. Show me sessions by region
81. Compare engagement between US and UK users
82. Which cities have the most users?

### By Operating System
83. Break down users by operating system
84. Compare iOS vs Android engagement
85. Which OS has the most crashes?

---

## Time-Based Analysis

### Trends
86. Show me user growth over the past 3 months
87. What day of the week has the most traffic?
88. Show me hourly session distribution
89. Compare this week to last week
90. What's the month-over-month change in page views?

### Specific Periods
91. How did Black Friday compare to normal days?
92. Show me metrics for the last 24 hours
93. What happened yesterday between 2pm and 4pm?
94. Compare weekday vs weekend engagement

---

## Advanced Queries

### Combined Analysis
95. Show me frustrated users on the checkout page who encountered errors
96. Find pages with poor LCP AND high rage clicks
97. What's the correlation between load time and form abandonment?
98. Show me mobile users with high frustration signals

### User-Level
99. Which users have the most sessions?
100. Show me identified users who encountered errors
101. Find users who visited more than 10 times this month

### Anomaly Detection
102. Are there any unusual spikes in errors today?
103. Show me pages with sudden drops in traffic
104. Find any abnormal patterns in conversion rates

---

## Tips for Asking Questions

### Be Specific About Time
- "last week" → Last 7 days
- "yesterday" → Previous day
- "today" → Current day
- "past month" → Last 30 days

### Specify Segments When Needed
- "on mobile" → Filter to mobile devices
- "in Chrome" → Filter to Chrome browser
- "in the US" → Filter to United States

### Ask for Comparisons
- "Compare X vs Y"
- "Week over week"
- "Mobile vs desktop"

### Request Visualizations
- "Show me a trend"
- "Break down by..."
- "Top 10..."

---

## Questions by Role

### Product Manager
- What features are users engaging with most?
- Where are users dropping off in the funnel?
- How is user engagement trending?

### Engineer
- What are the top errors affecting users?
- Which pages have performance issues?
- Are there any API endpoints failing?

### Designer
- Which elements are users clicking but not responding?
- Where do users stop scrolling?
- What pages have the highest frustration?

### Analyst
- What's driving the change in conversion rate?
- How do different segments behave differently?
- What's the correlation between performance and engagement?
