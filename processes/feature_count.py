from pywps import Process, ComplexInput, Format, LiteralOutput


class FeatureCount(Process):
    def __init__(self):
        inputs = [ComplexInput('layer', 'Layer', [Format('GML')])]
        outputs = [LiteralOutput('count', 'Count', data_type='integer')]
        
        super(FeatureCount, self).__init__(
            self._handler,
            identifier='feature_count',
            version='None',
            title='Feature count',
            abstract='This process counts the number of features in a vector',
            profile='',
            wsdl='',
            metadata=['Feature', 'Count'],
            inputs=inputs,
            outputs=outputs,
            store_supported=True,
            status_supported=True
        ) 

    @staticmethod
    def _handler(request, response):
        import lxml.etree
        from pywps.app import xpath_ns
        doc = lxml.etree.parse(request.inputs['layer'].file)
        feature_elements = xpath_ns(doc, '//gml:featureMember')
        response.outputs['count'].data = len(feature_elements)
        return response      