package main
 
import (
	"fmt"
	"math/rand"
	"time"
	"github.com/aws/aws-lambda-go/lambda"
)

const Fruits = []string{
	"Orange",
	"Lime",
	"Mint",
	"Grapefruit",
}

type Event struct {
	Name 			string `json:"name"`
	Callback 	string `json:"callback"`
	Recipe		[]string `json:"recipe"`
}

func HandleLambdaEvent(event Event) (Event, error) {
	event.Recipe = append(event.Recipe, Fruits[rand.Intn(len(Fruits))])
	return event, nil
}
 
func main() {
	rand.Seed(time.Now().Unix()) // initialize global pseudo random generator
  lambda.Start(HandleLambdaEvent)
}    
