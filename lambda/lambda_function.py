import boto3
import uuid
import json

dynamodb = boto3.client('dynamodb')
TABLE_NAME = "url-shortener"

def lambda_handler(event, context):
    try:
        if event['httpMethod'] == 'POST':
            body = json.loads(event['body'])
            long_url = body.get('long_url')
            if not long_url:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': "Missing 'long_url' in request body"})
                }

            short_id = str(uuid.uuid4())[:8]
            dynamodb.put_item(
                TableName=TABLE_NAME,
                Item={
                    'id': {'S': short_id},
                    'long_url': {'S': long_url}
                }
            )

            return {
                'statusCode': 201,
                'body': json.dumps({
                    'short_url': f"https://{event['headers']['Host']}/{short_id}",
                    'long_url': long_url
                })
            }

        elif event['httpMethod'] == 'GET':
            short_id = event['pathParameters']['id']
            response = dynamodb.get_item(
                TableName=TABLE_NAME,
                Key={'id': {'S': short_id}}
            )
            if 'Item' not in response:
                return {
                    'statusCode': 404,
                    'body': json.dumps({'error': f"No URL found for ID {short_id}"})
                }

            long_url = response['Item']['long_url']['S']
            return {
                'statusCode': 302,
                'headers': {'Location': long_url}
            }

        return {
            'statusCode': 405,
            'body': json.dumps({'error': 'Method Not Allowed'})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

