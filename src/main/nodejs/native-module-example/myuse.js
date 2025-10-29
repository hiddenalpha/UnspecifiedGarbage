
const sum = require("./build/node-gyp/build/Release/mymodule").sum;
const result = sum(3, 5);
console.log("result is: ", result);

