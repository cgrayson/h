assert = require('chai').assert
_ = require('lodash')
types = require('leadconduit-types')
lcTypesParser = require('leadconduit-integration').test.types.parser
helper = require('../helper')

# some integrations declare request or response variables as these types even though they're not in leadconduit-types
types.names.push 'array'
types.names.push 'wildcard'

thisModule = helper.loadModule()

@integrations = helper.getIntegrations thisModule

describe 'Harness initialization', ->

  it 'should be able to load', ->
    assert.isDefined thisModule


for i of @integrations
  do (i) =>
    integration = helper.getIntegration @integrations, i

    describe integration.name, ->

      describe 'Module basics', ->

        it 'should have a valid type (if it has a type)', ->
          if integration.type?
            assert.isTrue integration.type is 'inbound' or integration.type is 'outbound', "type is 'inbound' or 'outbound'"


        it 'should have a validate function', ->

          assert.isDefined integration.validate
          assert.equal typeof integration.validate, 'function'


        it 'should have request()/response() or handle()', ->

          assert.isDefined integration.handle or (integration.request and integration.response)
          if integration.handle
            assert.equal typeof integration.handle, 'function'
          else
            assert.equal typeof integration.request, 'function'
            assert.equal typeof integration.response, 'function'


      describe 'Validate function', ->

        it 'should return a string', ->
          msg = integration.validate(lead: {})
          assert.equal typeof msg, 'string'
          assert.isTrue msg.length > 0


        it 'should correctly handle test fixtures', ->
          fixtures = integration.fixtures['validate']
          parser = lcTypesParser(integration.requestVariables())
          for fixture in fixtures
            vars = fixture.vars
            vars.lead = {} unless vars.lead? # there's always a `lead` on `vars`
            assert.equal integration.validate(parser(fixture.vars)), fixture.expected


      describe 'Request variables', ->

        before ->
          @variables = integration.requestVariables

        it 'should be declared', ->
          assert.isDefined @variables
          assert.equal typeof @variables, 'function'
          assert.isTrue Array.isArray @variables()
          assert.isTrue @variables().length > 0


        it 'should include all attributes', ->

          @variables().forEach (variable) ->
            assert.isDefined variable.name
            assert.isDefined variable.type, "type is defined on '#{variable.name}'"
            assert.isDefined variable.required, "required is defined on '#{variable.name}'"


        it 'should have valid values for name', ->
          @variables().forEach (variable) ->
            assert.isDefined variable.name
            assert.isTrue variable.name.length > 0, "name has non-zero length"
            assert.equal variable.name, variable.name.toLowerCase(), "name '#{variable.name}' has no uppercase letters"


        it 'should have valid values for description', ->
          @variables().forEach (variable) ->
            if variable.type isnt 'wildcard'
              assert.isDefined variable.description, "description is defined on '#{variable.name}'"
              assert.isTrue variable.description.length > 0, "description for '#{variable.name}' has non-zero length"


        it 'should have valid values for required', ->
          @variables().forEach (variable) ->
            assert.equal Boolean(variable.required), variable.required, "required attribute for '#{variable.name}' is valid boolean"


        it 'should have valid values for type', ->
          @variables().forEach (variable) ->
            valid = types.names.indexOf(variable.type) >= 0
            assert.isTrue valid, "type attribute for '#{variable.name}' is valid LeadConduit type"


      describe 'Response variables', ->

        before ->
          @variables = integration.responseVariables or integration.response?.variables

        it 'should be declared', ->
          assert.isDefined @variables
          assert.equal typeof @variables, 'function'
          assert.isTrue Array.isArray @variables()
          assert.isTrue @variables().length > 0

        it 'should include all attributes', ->

          @variables().forEach (variable) ->
            assert.isDefined variable.name
            assert.isDefined variable.type, "type is defined on '#{variable.name}'"


        it 'should have valid values for name', ->
          @variables().forEach (variable) ->
            assert.isDefined variable.name
            assert.isTrue variable.name.length > 0, "name has non-zero length"
            assert.equal variable.name, variable.name.toLowerCase(), "name '#{variable.name}' has no uppercase letters"


        it 'should have valid values for description', ->
          @variables().forEach (variable) ->
            if variable.type isnt 'wildcard'
              assert.isDefined variable.description, "description is defined on '#{variable.name}'"
              assert.isTrue variable.description.length > 0, "description for '#{variable.name}' has non-zero length"


        it 'should have valid values for type', ->
          @variables().forEach (variable) ->
            valid = types.names.indexOf(variable.type) >= 0
            assert.isTrue valid, "type attribute for '#{variable.name}' is valid LeadConduit type"


      describe 'Request function', ->

        it 'should correctly handle request fixtures', ->
          if integration.request
            parser = lcTypesParser(integration.requestVariables())
            fixtures = integration.fixtures['request']
            for fixture in fixtures
              vars = _.merge(fixture.vars, integration.fixtures.extra_vars)
              assertFixtureMatch integration.request(parser(vars)), fixture.expected


      describe 'Response function', ->

        it 'should correctly handle response fixtures', ->
          if integration.response
            fixtures = integration.fixtures['response']
            for fixture in fixtures
              assertFixtureMatch integration.response({}, {}, fixture.res), fixture.expected


      describe 'Handle function', ->

        if integration.handle
          integration.fixtures['handle'].forEach (fixture) ->

            it "should correctly handle #{fixture.description}", (done) ->
              vars = _.merge(fixture.vars, integration.fixtures.extra_vars)
              helper.invokeHandle integration.handle, vars, fixture.nockOptions, (err, event) ->
                console.error(err) if err
                assert.isNull err
                assert.deepEqual event, fixture.expected
                done()


assertFixtureMatch = (actual, expected) ->
  if _.isRegExp(expected)
    assert.match actual, expected
  else if _.isObject(expected)
    assert.deepEqual actual, expected
  else if _.isString(expected)
    assert.equal actual, expected
  else
    assert.fail(null, null, '"expected" in fixture should be a RegExp, Object, or String')

