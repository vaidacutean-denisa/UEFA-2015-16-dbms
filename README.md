## UEFA Database Management System (2015/16 season)

This project involves the development of a relational database designed to manage data concerning both domestic football leagues in UEFA member countries and international football tournaments regulated by the Union of European Football Associations (UEFA).

The proposed model is based on the 2015/2016 football season, which includes the European club competitions UEFA Champions League (UCL), UEFA Europa League (UEL), and the European Football Championship contested by the senior men's national teams of UEFA members (Euro 2016).

The domestic league of a country refers exclusively to the top national division. Additionally, the system is structured for senior men's professional football, serving as the primary focus for the model's competitive data. Therefore, youth competitions, women's football, and other age categories or competitive levels are not represented.

### Key Features
- **Comprehensive Data Modeling**: Tracks information for teams, players, coaches, sponsors, stadiums, and competition results.

- **Relational Logic**: The model implements core relationships between entities, including team-stadium ownership, sponsorship contracts, and match participation.

- **Procedural Logic**: Utilizes stored procedures, functions, packages, and triggers to handle match analysis and data integrity.

- **Performance Monitoring**: Includes functionalities to analyze team performance (ex: goal averages, match outcomes, player contributions) in domestic and international competitions.


### Constraints and Assumptions
The model adheres to the following competitive and structural constraints:

- **Club Affiliation**: Each club belongs to exactly one domestic championship.

- **Coaching**: A club may have multiple coaches, but must have at least one.

- **Player Registration**: A player is registered to only one club at a time and may optionally be called up to one national team.

- **Match Regulation**: Every official match requires a valid stadium and exactly two distinct participating teams.

- **Stadium Usage**: A stadium can host multiple matches, but not on the same day. Teams may own their stadium or rent one.

- **Simplifications (out of scope)**: Excludes winter transfer window data (only start-of-season rosters are considered).

- **Competition Scope**: Includes Euro 2016 as a structural competition entity, without individual match records.


## Project Modules

To complement the structural design and relational logic described above, the following modules have been implemented to handle complex database operations, automated business rules, and analytical tasks:

- `p6_collections.sql` (collection management): this procedure identifies the top three goal-scorers for each team within a given domestic championship and provides detailed statistics for all their goals across all competitions in the current season. It demonstrates the use of all three types of PL/SQL collections.

- `p7_cursors.sql` (cursor management): this module evaluates team performance in European competitions using a combination of parameterized cursors and cursors with subqueries. It filters teams based on specific performance criteria, such as a positive goal difference and sponsorship values that fall below their specific competition's average.

- `p8_function.sql` (function & exception handling): a functional module that retrieves the stadium name associated with a specific sponsored team. It ensures data integrity through robust handling of both system-predefined and custom exceptions.

- `p9_proc.sql`: this module uses advanced procedural logic to determine which opponent registered the most goals against a given team within the first $k$ minutes of a match. It utilizes multiple input/output parameters, performs complex multi-table joins, and incorporates custom exceptions to validate input ranges and ensure accurate data retrieval.  

- `trigger.sql`: This file contains a comprehensive suite of triggers dedicated to maintaining database integrity and auditing schema activity. It includes *row-level triggers* to synchronize goal counts in the MECI table and enforce stadium rules, *statement-level triggers* to regulate competition participation limits, and *DDL triggers* to log structural changes to the schema.

### Project Structure
The source code and design documentation are organized within the project root as follows:

- `src/`: Contains the PL/SQL modules and database scripts:

    - `create.sql`: Contains the DDL statements for creating the relational schema, including table definitions, sequences, and constraints.

    - `insert.sql`: Provides the initial data population scripts to set up the environment with sample teams, players, sponsors, and competitive records.

- `diagrams/`: Contains the visual modeling files for the project:

    - `er_diagram.png`: The Entity-Relationship diagram illustrating the physical database structure.
 
    - `conceptual_diagram.png`: The conceptual model depicting the business entities and their high-level relationships.
