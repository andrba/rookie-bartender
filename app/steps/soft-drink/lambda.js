const SOFT_DRINKS = [
  'Coca-cola',
  'Orange Juice',
  'Tomato Juice',
  'Pineapple Juice',
  'Coconut Cream',
  'Lemon Juice'
];

exports.handler = function(event, context, callback) {
  let softDrink = SOFT_DRINKS[Math.floor(Math.random() * SOFT_DRINKS.length)];

  event.recipe.push(softDrink);

  callback(null, event);
}
