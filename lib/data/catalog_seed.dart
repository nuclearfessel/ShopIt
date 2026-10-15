/// Built-in catalog of common supermarket items, grouped by category.
///
/// Categories are listed in a typical store walking order (the order is used
/// to group the shopping list). Written for Shop-it; it is not copied from any
/// other app. The seed is inserted when the database is created or migrated to
/// schema v2, so changing it later needs a new migration to reach existing
/// installs.
const Map<String, List<String>> catalogSeed = {
  'Produce': [
    'Apples', 'Avocados', 'Bananas', 'Basil', 'Bell peppers', 'Blueberries',
    'Broccoli', 'Cabbage', 'Carrots', 'Cauliflower', 'Celery', 'Cherries',
    'Cilantro', 'Corn on the cob', 'Cucumbers', 'Garlic', 'Ginger', 'Grapes',
    'Green beans', 'Green onions', 'Jalapenos', 'Kale', 'Lemons', 'Lettuce',
    'Limes', 'Mangoes', 'Mushrooms', 'Onions', 'Oranges', 'Parsley', 'Peaches',
    'Pears', 'Pineapple', 'Potatoes', 'Raspberries', 'Red onions', 'Romaine',
    'Spinach', 'Squash', 'Strawberries', 'Sweet potatoes', 'Tomatoes',
    'Watermelon', 'Zucchini',
  ],
  'Bakery': [
    'Bagels', 'Baguette', 'Bread', 'Brioche buns', 'Burger buns', 'Cake',
    'Cookies', 'Croissants', 'Dinner rolls', 'English muffins', 'Hot dog buns',
    'Muffins', 'Pita bread', 'Sourdough', 'Tortillas', 'Whole wheat bread',
  ],
  'Meat & Poultry': [
    'Bacon', 'Beef mince', 'Bratwurst', 'Chicken breasts', 'Chicken drumsticks',
    'Chicken thighs', 'Chicken wings', 'Ground beef', 'Ground turkey', 'Ham',
    'Hot dogs', 'Lamb chops', 'Pork chops', 'Pork loin', 'Ribs', 'Roast beef',
    'Sausages', 'Steak', 'Turkey breast', 'Whole chicken',
  ],
  'Seafood': [
    'Cod', 'Crab', 'Fish fillets', 'Haddock', 'Lobster', 'Mussels', 'Prawns',
    'Salmon', 'Sardines', 'Scallops', 'Shrimp', 'Tilapia', 'Tuna steaks',
  ],
  'Deli': [
    'Cooked chicken', 'Deli ham', 'Deli turkey', 'Hummus', 'Olives', 'Pastrami',
    'Prepared salad', 'Rotisserie chicken', 'Salami', 'Sliced cheese',
  ],
  'Dairy & Eggs': [
    'Butter', 'Buttermilk', 'Cheddar cheese', 'Cheese slices', 'Cottage cheese',
    'Cream', 'Cream cheese', 'Eggs', 'Feta', 'Greek yogurt', 'Half and half',
    'Margarine', 'Milk', 'Mozzarella', 'Oat milk', 'Parmesan', 'Almond milk',
    'Sour cream', 'Soy milk', 'Whipped cream', 'Yogurt',
  ],
  'Frozen': [
    'Fish fingers', 'Frozen berries', 'Frozen broccoli', 'Frozen chicken nuggets',
    'Frozen fries', 'Frozen peas', 'Frozen pizza', 'Frozen corn',
    'Frozen vegetables', 'Frozen waffles', 'Ice cream', 'Ice cubes',
    'Popsicles', 'Frozen meals',
  ],
  'Canned & Jarred': [
    'Baked beans', 'Black beans', 'Canned corn', 'Canned fruit', 'Canned tomatoes',
    'Canned tuna', 'Chickpeas', 'Chicken broth', 'Coconut milk', 'Kidney beans',
    'Pasta sauce', 'Peanut butter', 'Jam', 'Pickles', 'Soup', 'Tomato paste',
    'Vegetable broth', 'Honey', 'Maple syrup',
  ],
  'Pasta, Rice & Grains': [
    'Basmati rice', 'Brown rice', 'Couscous', 'Egg noodles', 'Lasagna sheets',
    'Macaroni', 'Noodles', 'Oats', 'Pasta', 'Quinoa', 'Rice', 'Spaghetti',
    'White rice', 'Instant noodles',
  ],
  'Baking': [
    'Baking powder', 'Baking soda', 'Brown sugar', 'Cake mix', 'Chocolate chips',
    'Cocoa powder', 'Cornstarch', 'Flour', 'Icing sugar', 'Self-raising flour',
    'Sugar', 'Vanilla extract', 'Yeast',
  ],
  'Spices & Seasonings': [
    'Black pepper', 'Cinnamon', 'Chili powder', 'Cumin', 'Curry powder',
    'Garlic powder', 'Italian seasoning', 'Oregano', 'Paprika', 'Salt',
    'Taco seasoning', 'Turmeric',
  ],
  'Condiments & Sauces': [
    'BBQ sauce', 'Hot sauce', 'Ketchup', 'Mayonnaise', 'Mustard', 'Pesto',
    'Relish', 'Salad dressing', 'Salsa', 'Soy sauce', 'Sriracha',
    'Teriyaki sauce', 'Worcestershire sauce',
  ],
  'Oils & Vinegars': [
    'Apple cider vinegar', 'Balsamic vinegar', 'Cooking spray', 'Olive oil',
    'Sesame oil', 'Vegetable oil', 'White vinegar', 'Coconut oil',
  ],
  'Breakfast & Cereal': [
    'Cereal', 'Cornflakes', 'Granola', 'Granola bars', 'Muesli', 'Pancake mix',
    'Porridge', 'Pop-tarts',
  ],
  'Snacks': [
    'Almonds', 'Cashews', 'Chocolate', 'Crackers', 'Crisps', 'Dried fruit',
    'Gum', 'Popcorn', 'Pretzels', 'Protein bars', 'Raisins', 'Rice cakes',
    'Tortilla chips', 'Trail mix', 'Walnuts', 'Sweets',
  ],
  'Beverages': [
    'Apple juice', 'Bottled water', 'Cola', 'Energy drinks', 'Ginger ale',
    'Lemonade', 'Orange juice', 'Sparkling water', 'Sports drinks', 'Squash',
    'Tonic water',
  ],
  'Coffee & Tea': [
    'Black tea', 'Coffee beans', 'Coffee filters', 'Creamer', 'Green tea',
    'Ground coffee', 'Herbal tea', 'Hot chocolate', 'Instant coffee', 'Tea bags',
  ],
  'Alcohol': [
    'Beer', 'Cider', 'Gin', 'Red wine', 'Rum', 'Vodka', 'Whisky', 'White wine',
    'Prosecco',
  ],
  'Baby': [
    'Baby food', 'Baby formula', 'Baby wipes', 'Diapers', 'Nappies',
  ],
  'Pet': [
    'Cat food', 'Cat litter', 'Dog food', 'Dog treats', 'Pet treats',
  ],
  'Household & Cleaning': [
    'Air freshener', 'Batteries', 'Bin bags', 'Bleach', 'Dish soap',
    'Dishwasher tablets', 'Fabric softener', 'Glass cleaner', 'Laundry detergent',
    'Light bulbs', 'Sponges', 'Surface cleaner', 'Toilet cleaner',
    'Washing-up liquid',
  ],
  'Paper & Wrap': [
    'Aluminum foil', 'Baking paper', 'Cling film', 'Freezer bags',
    'Napkins', 'Paper towels', 'Sandwich bags', 'Tissues', 'Toilet paper',
  ],
  'Personal Care': [
    'Body wash', 'Conditioner', 'Cotton buds', 'Deodorant', 'Floss',
    'Hand soap', 'Lotion', 'Mouthwash', 'Razors', 'Shampoo', 'Shaving cream',
    'Sunscreen', 'Toothbrush', 'Toothpaste',
  ],
  'Health & Pharmacy': [
    'Allergy tablets', 'Band-aids', 'Cough syrup', 'Hand sanitizer',
    'Ibuprofen', 'Paracetamol', 'Vitamins',
  ],
  'Other': [],
};
